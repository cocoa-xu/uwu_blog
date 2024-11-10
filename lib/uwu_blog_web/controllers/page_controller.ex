defmodule UwUBlogWeb.PageController do
  @moduledoc false

  alias UwUBlog.PostCollection

  use UwUBlog.Tracing.Decorator
  use UwUBlogWeb, :controller

  @decorate trace()
  def index(conn, _) do
    render(conn, "index.html")
  end

  @decorate trace()
  def post(conn, %{"permalink" => permalink}) do
    case PostCollection.get_post(permalink) do
      {:ok, post} ->
        render(conn, "post.html", post: post)

      {:error, :not_found} ->
        render(conn, "404.html")
    end
  end

  def extension_allowed?(path) do
    lower = String.downcase(path)
    Enum.any?(Enum.map([".jpg", ".jpeg", ".png", ".webp"], &String.ends_with?(lower, &1)))
  end

  @decorate trace()
  def assets(conn, _info = %{"permalink" => permalink, "assets" => assets}) do
    case PostCollection.permalink_to_dir(permalink) do
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
end
