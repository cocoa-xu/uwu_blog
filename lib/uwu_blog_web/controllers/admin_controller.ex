defmodule UwUBlogWeb.AdminController do
  use UwUBlogWeb, :controller

  def index(conn, _params) do
    render(conn, :index, credentials: UwUBlog.Passkeys.list_credentials())
  end
end
