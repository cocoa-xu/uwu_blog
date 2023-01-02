defmodule UwuBlogWeb.PageController do
  use UwuBlogWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
