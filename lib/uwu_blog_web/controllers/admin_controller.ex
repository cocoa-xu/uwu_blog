defmodule UwUBlogWeb.AdminController do
  use UwUBlogWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
