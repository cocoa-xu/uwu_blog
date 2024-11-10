defmodule UwUBlog.Post do
  @moduledoc false

  alias UwUBlog.PostPending

  use UwUBlog.Tracing.Decorator

  defstruct [
    :frontmatter,
    :permalink,
    :mtime,
    :entry,
    :dir,
    :content
  ]

  @type t :: %__MODULE__{
          frontmatter: map(),
          permalink: String.t(),
          mtime: DateTime.t(),
          entry: String.t(),
          dir: String.t(),
          content: String.t()
        }

  @doc """
  Process a post from a markdown file.
  """
  @spec process(PostPending.t() | t()) :: %__MODULE__{}
  def process(%{entry: markdown_file} = post) do
    markdown = File.read!(markdown_file)

    {frontmatter, content} = parse_frontmatter(markdown_file, markdown)
    {frontmatter, permalink} = standardize_frontmatter(markdown_file, frontmatter, content)

    html_content =
      Earmark.Transform.map_ast(
        Earmark.as_ast!(content, Earmark.Options.make_options!(code_class_prefix: "language-")),
        fn node ->
          case node do
            {"p", p_atts, [{"img", i_atts, content, i_meta}], p_meta} ->
              src =
                Enum.find_value(i_atts, fn
                  {"src", src} -> src
                  _ -> nil
                end)

              if !String.starts_with?(src, ["http://", "https://", "://"]) do
                i_atts =
                  Enum.reject(i_atts, fn
                    {"src", _} -> true
                    _ -> false
                  end)

                {:replace,
                 {"p", p_atts,
                  [{"img", [{"src", Path.join(permalink, src)}] ++ i_atts, content, i_meta}],
                  p_meta}}
              else
                node
              end

            _ ->
              node
          end
        end,
        true
      )
      |> Earmark.Transform.transform()

    %__MODULE__{
      frontmatter: frontmatter,
      permalink: permalink,
      mtime: File.stat!(markdown_file).mtime,
      entry: markdown_file,
      dir: post.dir,
      content: html_content
    }
  end

  @decorate trace()
  defp parse_frontmatter(markdown_file, "---\n" <> markdown) do
    with [frontmatter_yaml, rest] <- String.split(markdown, "---\n", parts: 2, trim: true),
         {:ok, frontmatter} <- YamlElixir.read_from_string(frontmatter_yaml) do
      {frontmatter, rest}
    else
      _ ->
        parse_frontmatter(markdown_file, :phoenix, markdown)
    end
  end

  defp parse_frontmatter(markdown_file, :phoenix, markdown) do
    String.replace(Path.basename(markdown_file), ".md", "")
    |> then(fn filename ->
      {{y, m, d}, _} = File.stat!(markdown_file).mtime
      mm = String.pad_leading("#{m}", 2, "0")
      dd = String.pad_leading("#{d}", 2, "0")

      frontmatter = %{
        title: Phoenix.Naming.humanize(filename),
        date: "#{y}-#{mm}-#{dd}"
      }

      {frontmatter, markdown}
    end)
  end

  @decorate trace()
  defp standardize_frontmatter(markdown_file, frontmatter, content) do
    permalink = frontmatter["permalink"]

    {frontmatter, permalink} =
      if permalink == nil do
        permalink = permalink_from_filename(markdown_file)
        {Map.put(frontmatter, "permalink", permalink), permalink}
      else
        {frontmatter, permalink}
      end

    excerpt = frontmatter["excerpt"]

    frontmatter =
      if excerpt == nil do
        excerpt =
          case Earmark.Parser.as_ast(content) do
            {:ok, [first | _], _} ->
              Earmark.Transform.transform(first)

            _ ->
              ""
          end

        Map.put(frontmatter, "excerpt", excerpt)
      else
        frontmatter
      end

    {frontmatter, permalink}
  end

  @decorate trace()
  defp permalink_from_filename(markdown_file) do
    markdown_file
    |> Path.basename()
    |> String.replace(".md", "")
    |> String.replace("_", "-")
  end
end
