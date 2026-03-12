defmodule UwUBlog.PostTest do
  use UwUBlog.DataCase, async: true

  alias UwUBlog.Post
  alias UwUBlog.PostPending

  @posts_dir "posts"

  describe "process/1" do
    test "processes a markdown file with YAML frontmatter" do
      post = Post.process(%PostPending{entry: "posts/write_a_blog_from_zero.md", dir: @posts_dir})

      assert %Post{} = post
      assert post.frontmatter["title"] != nil
      assert post.frontmatter["permalink"] != nil
      assert post.permalink == post.frontmatter["permalink"]
      assert is_binary(post.content)
      assert post.entry == "posts/write_a_blog_from_zero.md"
    end

    test "processes the embedded template post and preserves template frontmatter" do
      post =
        Post.process(%PostPending{entry: "posts/embed_phoenix_templates.md", dir: @posts_dir})

      assert %Post{} = post
      assert post.frontmatter["title"] == "Embedding Phoenix Templates in Markdown Files"
      assert post.frontmatter["permalink"] == "embedding-phoenix-templates-in-markdown"

      # The template frontmatter should be preserved
      assert %{"heex" => heex, "using" => "embed.html"} = post.frontmatter["template"]
      assert is_binary(heex)
      assert heex =~ "<article"
      assert heex =~ "Phoenix.HTML.raw"
    end

    test "generates permalink from filename when not specified in frontmatter" do
      # Create a temporary markdown file without permalink
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "test_post_no_permalink.md")

      File.write!(tmp_file, """
      ---
      title: Test Post
      date: 2024-01-01
      ---

      Hello world!
      """)

      on_exit(fn -> File.rm(tmp_file) end)

      post = Post.process(%PostPending{entry: tmp_file, dir: tmp_dir})

      assert post.permalink == "test-post-no-permalink"
    end

    test "renders markdown content to HTML" do
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "test_render.md")

      File.write!(tmp_file, """
      ---
      title: Render Test
      date: 2024-01-01
      permalink: render-test
      ---

      ## Hello

      This is a **bold** paragraph.
      """)

      on_exit(fn -> File.rm(tmp_file) end)

      post = Post.process(%PostPending{entry: tmp_file, dir: tmp_dir})

      assert post.content =~ "<h2>"
      assert post.content =~ "Hello"
      assert post.content =~ "<strong>bold</strong>"
    end

    test "auto-generates excerpt from first paragraph when not provided" do
      tmp_dir = System.tmp_dir!()
      tmp_file = Path.join(tmp_dir, "test_excerpt.md")

      File.write!(tmp_file, """
      ---
      title: Excerpt Test
      date: 2024-01-01
      permalink: excerpt-test
      ---

      First paragraph content here.

      Second paragraph.
      """)

      on_exit(fn -> File.rm(tmp_file) end)

      post = Post.process(%PostPending{entry: tmp_file, dir: tmp_dir})

      assert post.frontmatter["excerpt"] =~ "First paragraph"
    end
  end

  describe "is_image_url?/1" do
    test "returns true for HTTP URLs" do
      assert Post.is_image_url?("http://example.com/image.png")
      assert Post.is_image_url?("https://example.com/image.png")
    end

    test "returns false for relative paths" do
      refute Post.is_image_url?("image.png")
      refute Post.is_image_url?("./image.png")
    end
  end
end
