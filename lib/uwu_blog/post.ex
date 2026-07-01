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

  # Render with raw HTML passed through (posts embed trusted HTML) and MDEx's
  # built-in syntax highlighter off, so fenced blocks keep the plain
  # `<code class="language-*">` markup the client-side highlighter expects.
  @mdex_opts [render: [unsafe: true], syntax_highlight: nil]

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

    html_content = process_content_to_ast(content, context)

    %__MODULE__{
      frontmatter: frontmatter,
      permalink: permalink,
      mtime: File.stat!(markdown_file).mtime,
      entry: markdown_file,
      dir: post.dir,
      content: html_content
    }
  end

  @doc """
  Cheaply resolve a post's permalink without rendering its content.

  Reads only the frontmatter (or derives it from the filename), so the collection
  can index every post by permalink without paying the full Markdown + asset-upload
  cost of `process/1` up front.
  """
  @spec resolve_permalink(String.t()) :: String.t()
  def resolve_permalink(markdown_file) do
    with {:ok, "---\n" <> _ = markdown} <- File.read(markdown_file),
         {frontmatter, _content} <- parse_frontmatter(markdown_file, markdown),
         permalink when is_binary(permalink) <- frontmatter["permalink"] do
      permalink
    else
      _ -> permalink_from_filename(markdown_file)
    end
  end

  @decorate trace()
  def process_content_to_ast(content, context) do
    content
    |> MDEx.parse_document!()
    |> MDEx.traverse_and_update(&handle_node(&1, context))
    |> MDEx.to_html!(@mdex_opts)
  end

  def handle_node(%MDEx.Image{url: url} = node, context) do
    if is_image_url?(url) do
      node
    else
      %{node | url: maybe_upload_image(context, url)}
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
          case MDEx.parse_document!(content) do
            %MDEx.Document{nodes: [first | _]} ->
              MDEx.to_html!(%MDEx.Document{nodes: [first]}, @mdex_opts)

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
