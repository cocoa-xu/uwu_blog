defmodule UwUBlog.Post do
  @moduledoc false

  alias UwUBlog.PostPending
  alias UwUBlog.Storage
  alias UwUBlog.Blog.Asset
  alias UwUBlog.Repo

  use UwUBlog.Tracing.Decorator

  require Logger

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
  @decorate trace()
  @spec process(PostPending.t() | t()) :: %__MODULE__{}
  def process(%{entry: markdown_file} = post) do
    markdown = File.read!(markdown_file)

    {frontmatter, content} = parse_frontmatter(markdown_file, markdown)
    {frontmatter, permalink} = standardize_frontmatter(markdown_file, frontmatter, content)

    context = %{
      permalink: permalink,
      dir: post.dir
    }

    html_content =
      process_content_to_ast(content, context, earmark_opts: [code_class_prefix: "language-"])

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
  def process_content_to_ast(content, context, opts \\ []) do
    content
    |> Earmark.as_ast!(Earmark.Options.make_options!(opts[:earmark_opts] || []))
    |> Earmark.Transform.map_ast(&handle_node(&1, context), true)
    |> Earmark.Transform.transform()
  end

  def handle_node(node = {"p", p_atts, [{"img", i_atts, content, i_meta}], p_meta}, context) do
    {src, i_atts} =
      Enum.reduce(i_atts, {nil, []}, fn
        {"src", src}, {nil, other} ->
          if is_image_url?(src) do
            {nil, other}
          else
            {src, other}
          end

        attr, {src, other} ->
          {src, [attr | other]}
      end)

    if src do
      img_src = maybe_upload_image(context, src)

      {:replace, {"p", p_atts, [{"img", [{"src", img_src}] ++ i_atts, content, i_meta}], p_meta}}
    else
      node
    end
  end

  def handle_node(node, _context), do: node

  def is_image_url?(url) when is_binary(url) do
    String.starts_with?(url, ["http://", "https://", "://"])
  end

  def is_image_url?(_), do: false

  @decorate trace()
  def maybe_upload_image(context, src) do
    image_filepath = Path.join(context.dir, src)
    key = Path.join(context.permalink, src)

    if Storage.available?() do
      upload_file_if_updated(image_filepath, key)
    else
      key
    end
  end

  @decorate trace()
  @spec upload_file_if_updated(String.t(), String.t()) :: String.t()
  defp upload_file_if_updated(image_filepath, key) do
    case Asset.file_updated?(image_filepath, key) do
      {:ok,
       %{
         updated?: updated?,
         asset: asset,
         public_url: public_url,
         mtime: mtime,
         checksum: checksum
       }} ->
        url =
          if updated? do
            case Storage.put(image_filepath, key) do
              {:ok, public_url} ->
                Logger.info(
                  "Uploaded image, local_path=#{image_filepath}, key=#{key}, public_url=#{public_url}"
                )

                public_url

              {:error, reason} ->
                Logger.error(
                  "Error uploading image: local_path=#{image_filepath}, key=#{key}: #{reason}"
                )

                key
            end
          else
            public_url
          end

        if asset do
          Repo.update!(
            Asset.changeset(asset, %{public_url: url, mtime: mtime, checksum: checksum})
          )
        else
          Repo.insert!(%Asset{
            type: :image,
            key: key,
            public_url: url,
            mtime: mtime,
            checksum: checksum
          })
        end

        url

      {:error, reason} ->
        Logger.error("Error uploading image: #{image_filepath}: #{reason}")

        key
    end
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
