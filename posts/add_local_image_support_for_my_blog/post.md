---
title: "Add Local Image Support for My Blog"
date: 2023-08-19
permalink: add-local-image-support-for-my-blog
---

Should've done this months ago XD

So I noticed a big issue for my blog a few months ago, and that was I can only use public accessible images for my blog posts. But uploading images to somewhere else first is definitely not the best writing experience.

Hence I decided to add support for using local images, which means the blog post and all its images will be put in a directory, and of course, these images can be put into any deeper level sub-directories.

Therefore, we can use single markdown files for simple posts and using a directory for posts that have other assets like images. For example, this post is located in a directory named `adding_image_support_to_my_blog`, and the local image is inside a sub-directory named `assets` (of course, you can use any other directory name other than `assets`).

```sh
posts
├── add_local_image_support_for_my_blog
│   ├── assets
│   │   └── DSC01247.jpeg
│   └── post.md
├── embed_phoenix_templates.md
├── sharing_now_playing.md
└── write_a_blog_from_zero.md
```

As for the URL to the image, I'd like to follow this pattern,

```
https://uwucocoa.moe/posts/:permalink/*assets
```

where `:permalink` is the permanent link to the post, and `*assets` will take everything after the `:permalink`. In this example, `DSC01247.jpeg` can be accessed at

```
https://uwucocoa.moe/posts/add-local-image-support-for-my-blog/assets/DSC01247.jpeg

:permalink => "adding-image-support-for-my-blog"
*assets => ["assets", "DSC01247.jpeg"]
```

Just like this

![screenshot](assets/DSC01247.jpeg)

# Implement This Feature in Phoenix
It's actually not that hard after figuring out what we need to do. 

First of all, we can add this rule to the router (in `router.ex`)

```elixir
scope "/", UwUBlogWeb do
  pipe_through :browser

  get "/", PageController, :index
  get "/post/:permalink", PageController, :post
  get "/post/:permalink/*assets", PageController, :assets
end
```

Then in `post.ex` we should add a `dir` metadata-entry to each post, indicating which directory the post resides.

```elixir
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
```

After that, we need a function to find the post based on the unique permanlink (in `post.ex`)

```elixir
def permalink_to_dir(permalink) do
  case get_post(permalink) do
    {:ok, post} ->
      {:ok, post.dir}

    _ ->
      {:error, :not_found}
  end
end
```

And once that's done, we need to replace the hyperlink when we are using local images. It can be done by parsing the markdown content to an AST and replace such nodes.

```elixir
def process(post) do
  markdown_file = post.entry
  markdown = File.read!(markdown_file)
  {frontmatter, content} = parse_frontmatter(markdown_file, markdown)
  {frontmatter, permalink} = standardize_frontmatter(markdown_file, frontmatter, content)

  html_content =
    Earmark.Transform.map_ast(
      Earmark.as_ast!(content),
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
    |> Earmark.Transform.transform(
      Earmark.Options.make_options!(code_class_prefix: "language-")
    )

  %{
    frontmatter: frontmatter,
    permalink: permalink,
    mtime: File.stat!(markdown_file).mtime,
    entry: markdown_file,
    dir: post.dir,
    content: html_content
  }
end
```

Lastly, in `page_controller.ex` we want restrict extensions to one of these and verify there is no directory traversal attack.

```elixir
def extension_allowed?(path) do
  lower = String.downcase(path)
  Enum.any?(Enum.map([".jpg", ".jpeg", ".png", ".webp"]), &String.ends_with?(lower, &1))
end

def assets(conn, info = %{"permalink" => permalink, "assets" => assets}) do
  case UwUBlog.Post.permalink_to_dir(permalink) do
    {:ok, post_dir} ->
      asset_path = Path.expand(Path.join(post_dir, Path.expand(Path.join(["/"] ++ assets))))

      if extension_allowed?(asset_path) && File.regular?(asset_path) do
        send_file(conn, 200, asset_path)
      else
        send_resp(conn, 404, "Not found")
      end

    _ ->
      send_resp(conn, 404, "Not found")
  end
end
```
