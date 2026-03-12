defmodule UwUBlogWeb.PageControllerTest do
  use UwUBlogWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Recent Posts"
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, "/about")
    assert html_response(conn, 200)
  end

  test "GET /post/:permalink renders a regular post", %{conn: conn} do
    conn = get(conn, "/post/write-a-blog-from-zero")
    response = html_response(conn, 200)
    assert response =~ "post"
  end

  test "GET /post/:permalink renders the embedded template post", %{conn: conn} do
    conn = get(conn, "/post/embedding-phoenix-templates-in-markdown")
    response = html_response(conn, 200)

    # The embedded template includes a <details> element showing the template source
    assert response =~ "<details"
    assert response =~ "Show template used in this post"
    # The post content should be rendered
    assert response =~ "Embedding Phoenix Templates in Markdown Files"
  end

  test "GET /post/:nonexistent returns 404", %{conn: conn} do
    conn = get(conn, "/post/this-post-does-not-exist-at-all")
    assert html_response(conn, 200) =~ "404"
  end

  describe "extension_allowed?/1" do
    test "allows image extensions" do
      assert UwUBlogWeb.PageController.extension_allowed?("photo.jpg")
      assert UwUBlogWeb.PageController.extension_allowed?("photo.jpeg")
      assert UwUBlogWeb.PageController.extension_allowed?("photo.png")
      assert UwUBlogWeb.PageController.extension_allowed?("photo.webp")
    end

    test "rejects non-image extensions" do
      refute UwUBlogWeb.PageController.extension_allowed?("file.txt")
      refute UwUBlogWeb.PageController.extension_allowed?("script.js")
      refute UwUBlogWeb.PageController.extension_allowed?("file.exe")
    end
  end
end
