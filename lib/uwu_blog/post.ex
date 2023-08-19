defmodule UwUBlog.Post do
  @moduledoc false
  require Logger
  use Agent

  def start_link(_) do
    Agent.start_link(
      fn ->
        %{posts: []}
      end,
      name: __MODULE__
    )
  end

  def posts_dir, do: "posts"

  def parse_posts do
    Agent.get_and_update(__MODULE__, fn
      %{posts: []} = state ->
        posts = _parse_post()
        {%{posts: posts}, state}

      state ->
        {state, state}
    end)
  end

  defp _parse_post do
    posts_dir = posts_dir()

    single_files =
      Enum.map(Path.wildcard(Path.join(posts_dir, "*.md")), fn entry ->
        %{dir: posts_dir, entry: entry}
      end)

    dir_entries =
      case File.ls(posts_dir) do
        {:ok, entries} ->
          entries
          |> Enum.filter(&File.dir?("#{posts_dir}/#{&1}"))
          |> Enum.map(&Path.join([posts_dir, &1]))
          |> Enum.map(fn sub_dir ->
            Enum.map(Path.wildcard(Path.join(sub_dir, "*.md")), fn entry ->
              %{dir: sub_dir, entry: entry}
            end)
          end)
          |> List.flatten()

        _ ->
          []
      end

    (single_files ++ dir_entries)
    |> Enum.sort_by(
      fn %{entry: entry} ->
        File.stat!(entry).mtime
      end,
      :desc
    )
    |> Enum.map(&process(&1))
  end

  def get_post(permalink) do
    Agent.get_and_update(__MODULE__, fn
      %{posts: []} ->
        posts = _parse_post()
        find_post(%{posts: posts}, permalink)

      state ->
        find_post(state, permalink)
    end)
  end

  def find_post(state = %{posts: posts}, permalink) do
    post_index =
      Enum.find_index(posts, fn post ->
        post.permalink == permalink
      end)

    {post, state} =
      if post_index do
        post = Enum.at(posts, post_index)

        if File.exists?(post.entry) do
          if post.mtime != File.stat!(post.entry).mtime do
            updated = process(post)
            state = %{posts: List.replace_at(posts, post_index, updated)}
            {updated, state}
          else
            {post, state}
          end
        else
          {nil, %{posts: List.delete_at(posts, post_index)}}
        end
      else
        {nil, state}
      end

    if post do
      {{:ok, post}, state}
    else
      {{:error, :not_found}, state}
    end
  end

  def find_post(state, _permalink) do
    {{:error, :not_found}, state}
  end

  def process(post) do
    markdown_file = post.entry
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

    %{
      frontmatter: frontmatter,
      permalink: permalink,
      mtime: File.stat!(markdown_file).mtime,
      entry: markdown_file,
      dir: post.dir,
      content: html_content
    }
  end

  def permalink_to_dir(permalink) do
    case get_post(permalink) do
      {:ok, post} ->
        {:ok, post.dir}

      _ ->
        {:error, :not_found}
    end
  end

  def standardize_frontmatter(markdown_file, frontmatter, content) do
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
          case EarmarkParser.as_ast(content) do
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

  def permalink_from_filename(markdown_file) do
    String.replace(String.replace(Path.basename(markdown_file), ".md", ""), "_", "-")
  end

  def parse_frontmatter(markdown_file, "---\n" <> markdown) do
    with [frontmatter_yaml, rest] <- String.split(markdown, "---\n", parts: 2, trim: true),
         {:ok, frontmatter} <- YamlElixir.read_from_string(frontmatter_yaml) do
      {frontmatter, rest}
    else
      _ ->
        parse_frontmatter(markdown_file, :phoenix, markdown)
    end
  end

  def parse_frontmatter(markdown_file, :phoenix, markdown) do
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
end
