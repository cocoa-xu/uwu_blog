defmodule UwUBlogWeb.PageController do
  use UwUBlogWeb, :controller

  def index(conn, _) do
    render(conn, "index.html")
  end

  def post(conn, %{"permalink" => permalink}) do
    case UwUBlog.Post.get_post(permalink) do
      {:ok, post} ->
        render(conn, "post.html", post: post)

      {:error, :not_found} ->
        render(conn, "404.html")
    end
  end
end
