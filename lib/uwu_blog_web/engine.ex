defmodule UwUBlog.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers embedded heex templates.

  It works by adding a HTML parsing and validation layer on top
  of EEx engine. By default it uses `Phoenix.LiveView.Engine` as
  its "subengine".
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  @doc false
  def compile(string, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)

    EEx.compile_string(string,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: "nofile",
      trim: trim,
      caller: [],
      source: string,
      tag_handler: __MODULE__
    )
  end

  @behaviour Phoenix.LiveView.TagEngine

  @impl true
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}
  def classify_type(":" <> name), do: {:slot, name}

  def classify_type(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, name}

  def classify_type("."), do: {:error, "a component name is required after ."}
  def classify_type("." <> name), do: {:local_component, name}
  def classify_type(name), do: {:tag, name}

  @impl true
  for void <- ~w(area base br col hr img input link meta param command keygen source) do
    def void?(unquote(void)), do: true
  end

  def void?(_), do: false

  @impl true
  def handle_attributes(ast, meta) do
    if is_list(ast) and literal_keys?(ast) do
      # Optimization: if keys are known at compilation time, we
      # inline the dynamic attributes
      attrs =
        Enum.map(ast, fn {key, value} ->
          name = to_string(key)

          case handle_attr_escape(name, value, meta) do
            :error -> handle_attrs_escape([{safe_unless_special(name), value}], meta)
            parts -> {name, parts}
          end
        end)

      {:attributes, attrs}
    else
      {:quoted, handle_attrs_escape(ast, meta)}
    end
  end

  defp literal_keys?([{key, _value} | rest]) when is_atom(key) or is_binary(key),
    do: literal_keys?(rest)

  defp literal_keys?([]), do: true
  defp literal_keys?(_other), do: false

  defp handle_attrs_escape(attrs, meta) do
    quote line: meta[:line] do
      unquote(__MODULE__).attributes_escape(unquote(attrs))
    end
  end

  defp handle_attr_escape("class", [head | tail], meta) when is_binary(head) do
    {bins, tail} = Enum.split_while(tail, &is_binary/1)
    encoded = class_attribute_encode([head | bins])

    if tail == [] do
      [IO.iodata_to_binary(encoded)]
    else
      tail =
        quote line: meta[:line] do
          {:safe, unquote(__MODULE__).class_attribute_encode(unquote(tail))}
        end

      [IO.iodata_to_binary([encoded, ?\s]), tail]
    end
  end

  defp handle_attr_escape("class", value, meta) do
    [
      quote(
        line: meta[:line],
        do: {:safe, unquote(__MODULE__).class_attribute_encode(unquote(value))}
      )
    ]
  end

  defp handle_attr_escape("style", value, meta) do
    [
      quote(
        line: meta[:line],
        do: {:safe, unquote(__MODULE__).empty_attribute_encode(unquote(value))}
      )
    ]
  end

  defp handle_attr_escape(_name, value, meta) do
    case extract_binaries(value, true, [], meta) do
      :error -> :error
      reversed -> Enum.reverse(reversed)
    end
  end

  defp extract_binaries({:<>, _, [left, right]}, _root?, acc, meta) do
    extract_binaries(right, false, extract_binaries(left, false, acc, meta), meta)
  end

  defp extract_binaries({:<<>>, _, parts} = binary, _root?, acc, meta) do
    Enum.reduce(parts, acc, fn
      part, acc when is_binary(part) ->
        [binary_encode(part) | acc]

      {:"::", _, [binary, {:binary, _, _}]}, acc ->
        [quoted_binary_encode(binary, meta) | acc]

      _, _ ->
        throw(:unknown_part)
    end)
  catch
    :unknown_part ->
      [quoted_binary_encode(binary, meta) | acc]
  end

  defp extract_binaries(binary, _root?, acc, _meta) when is_binary(binary),
    do: [binary_encode(binary) | acc]

  defp extract_binaries(value, false, acc, meta),
    do: [quoted_binary_encode(value, meta) | acc]

  defp extract_binaries(_value, true, _acc, _meta),
    do: :error

  @doc false
  def attributes_escape(attrs) do
    # We don't want to dasherize keys, which Phoenix.HTML does for atoms,
    # so we convert those to strings
    attrs
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      other -> other
    end)
    |> Phoenix.HTML.attributes_escape()
  end

  @doc false
  def class_attribute_encode(list) when is_list(list),
    do: list |> class_attribute_list() |> Phoenix.HTML.Engine.encode_to_iodata!()

  def class_attribute_encode(other),
    do: empty_attribute_encode(other)

  defp class_attribute_list(value) do
    value
    |> Enum.flat_map(fn
      nil -> []
      false -> []
      inner when is_list(inner) -> [class_attribute_list(inner)]
      other -> [other]
    end)
    |> Enum.join(" ")
  end

  @doc false
  def empty_attribute_encode(nil), do: ""
  def empty_attribute_encode(false), do: ""
  def empty_attribute_encode(true), do: ""
  def empty_attribute_encode(value), do: Phoenix.HTML.Engine.encode_to_iodata!(value)

  @doc false
  def binary_encode(value) when is_binary(value) do
    value
    |> Phoenix.HTML.Engine.encode_to_iodata!()
    |> IO.iodata_to_binary()
  end

  def binary_encode(value) do
    raise ArgumentError, "expected a binary in <>, got: #{inspect(value)}"
  end

  defp quoted_binary_encode(binary, meta) do
    quote line: meta[:line] do
      {:safe, unquote(__MODULE__).binary_encode(unquote(binary))}
    end
  end

  # We mark attributes as safe so we don't escape them
  # at rendering time. However, some attributes are
  # specially handled, so we keep them as strings shape.
  defp safe_unless_special("id"), do: :id
  defp safe_unless_special("aria"), do: :aria
  defp safe_unless_special("class"), do: :class
  defp safe_unless_special("data"), do: :data
  defp safe_unless_special(name), do: {:safe, name}

  @impl true
  def annotate_body(_) do
  end

  @impl true
  def annotate_caller(_, _) do
  end
end
