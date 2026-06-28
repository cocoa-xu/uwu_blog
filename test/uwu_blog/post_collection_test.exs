defmodule UwUBlog.PostCollectionTest do
  # Exercises the ETS-backed read path against the instance the application boots
  # (eager-compiled from the real `posts/` dir). No DB: storage is unconfigured in
  # test, so compilation never uploads assets.
  use ExUnit.Case, async: true

  alias UwUBlog.Post
  alias UwUBlog.PostCollection

  test "get_all_posts/0 returns compiled posts, newest first" do
    posts = PostCollection.get_all_posts()

    assert posts != []
    assert Enum.all?(posts, &match?(%Post{content: content} when is_binary(content), &1))

    mtimes = Enum.map(posts, & &1.mtime)
    assert mtimes == Enum.sort(mtimes, :desc)
  end

  test "get_post/1 serves a known post by its frontmatter permalink" do
    assert {:ok, %Post{permalink: "blog-from-scratch"} = post} =
             PostCollection.get_post("blog-from-scratch")

    assert post.content =~ "<"
  end

  test "get_post/1 returns :not_found for an unknown permalink" do
    assert {:error, :not_found} = PostCollection.get_post("definitely-not-a-real-post")
  end

  test "permalink_to_dir/1 resolves without compiling the post" do
    assert {:ok, dir} = PostCollection.permalink_to_dir("blog-from-scratch")
    assert File.dir?(dir)
    assert {:error, :not_found} = PostCollection.permalink_to_dir("definitely-not-a-real-post")
  end
end
