defmodule UwUBlog.Post do
  @moduledoc false
  use Agent

  def start_link(_) do
    Agent.start_link(fn ->
      %{posts: []}
    end, name: __MODULE__)
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
    Path.wildcard(Path.join(posts_dir(), "*.md"))
    |> Enum.sort_by(&(File.stat!(&1).mtime), :desc)
    |> Enum.map(&process(&1))
  end

  def get_post(slogan) do
    Agent.get_and_update(__MODULE__, fn
      %{posts: []} ->
        posts = _parse_post()
        find_post(%{posts: posts}, slogan)
      state ->
        find_post(state, slogan)
    end)
  end

  def find_post(state=%{posts: posts}, slogan) do
    post_index = Enum.find_index(posts, fn post ->
      post.slogan == slogan
    end)
    {post, state} =
      if post_index do
        post = Enum.at(posts, post_index)
        if File.exists?(post.file) do
          if post.mtime != File.stat!(post.file).mtime do
            updated = process(post.file)
            state = List.replace_at(posts, post_index, updated)
            {updated, state}
          else
            {post, state}
          end
        else
          {nil, List.delete_at(posts, post_index)}
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

  def find_post(state, _slogan) do
    {{:error, :not_found}, state}
  end

  def process(markdown_file) do
    markdown = File.read!(markdown_file)
    {frontmatter, content} = parse_frontmatter(markdown_file, markdown)
    {frontmatter, slogan} = standardize_frontmatter(markdown_file, frontmatter, content)

    %{
      frontmatter: frontmatter,
      slogan: slogan,
      mtime: File.stat!(markdown_file).mtime,
      file: markdown_file,
      content: Earmark.as_html!(content, Earmark.Options.make_options!(code_class_prefix: "language-"))
    }
  end

  def standardize_frontmatter(markdown_file, frontmatter, _content) do
    slogan = frontmatter["slogan"]
    {frontmatter, slogan} =
      if slogan == nil do
        slogan = slogan_from_filename(markdown_file)
        {Map.put(frontmatter, "slogan", slogan), slogan}
      else
        {frontmatter, slogan}
      end

    frontmatter = Map.put(frontmatter, "description", "Test")
    {frontmatter, slogan}
  end

  def slogan_from_filename(markdown_file) do
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
