defmodule UwUBlogWeb.PageController do
  @moduledoc false

  alias UwUBlog.PostCollection
  alias UwUBlog.NowPlaying

  use UwUBlog.Tracing.Decorator
  use UwUBlogWeb, :controller

  # The blog is read-mostly and identical for every visitor, so let the Cloudflare
  # edge serve these pages. `s-maxage` bounds edge staleness; `stale-while-
  # revalidate` keeps responses instant while the edge refreshes in the background.
  @index_cache "public, max-age=60, s-maxage=120, stale-while-revalidate=86400"
  @about_cache "public, max-age=300, s-maxage=86400, stale-while-revalidate=604800"
  @post_cache "public, max-age=300, s-maxage=600, stale-while-revalidate=86400"
  @asset_cache "public, max-age=2592000"
  @no_store "private, no-store"

  @decorate trace()
  def index(conn, _) do
    conn
    |> cache(@index_cache)
    |> render("index.html")
  end

  @decorate trace()
  def about(conn, _) do
    conn
    |> cache(@about_cache)
    |> render("about.html")
  end

  @decorate trace()
  def update_track(conn, params) do
    {status_code, resp} = NowPlaying.update_track(params)

    send_resp(conn, status_code, Jason.encode!(resp))
  end

  @decorate trace()
  def post(conn, %{"permalink" => permalink}) do
    case PostCollection.get_post(permalink) do
      {:ok, post} ->
        conn
        |> cache(@post_cache)
        |> render("post.html", post: post)

      {:error, :not_found} ->
        # Don't let the edge cache a miss — a not-yet-published post must not be
        # masked by a stale 404.
        conn
        |> cache(@no_store)
        |> render("404.html")
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
          conn
          |> cache(@asset_cache)
          |> send_file(200, asset_path)
        else
          send_resp(cache(conn, @no_store), 404, "Not found")
        end

      _ ->
        send_resp(cache(conn, @no_store), 404, "Not found")
    end
  end

  defp cache(conn, value), do: put_resp_header(conn, "cache-control", value)
end
