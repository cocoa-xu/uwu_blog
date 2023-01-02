defmodule UwUBlogWeb.PageController do
  use UwUBlogWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
