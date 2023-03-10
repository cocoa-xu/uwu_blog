defmodule UwUBlogWeb.Plugs.NowPlaying do
  import Plug.Conn
  use UwUBlogWeb, :controller
  use Agent

  def start_link(_) do
    Agent.start_link(
      fn ->
        %{now_playing: %{}}
      end,
      name: __MODULE__
    )
  end

  def init(default), do: default

  defp api_key, do: Application.fetch_env!(:uwu_blog, __MODULE__)[:apikey]
  defp timeout, do: 10

  defp remove_timeout(now_playing) do
    Map.filter(now_playing, fn {_, v} ->
      :erlang.monotonic_time(:second) - Map.get(v, "last_seen", 0) < timeout()
    end)
  end

  def call(
        %Plug.Conn{
          params: %{
            "apikey" => apikey,
            "type" => type,
            "data" => data,
            "current_time" => current_time,
            "duration" => duration,
            "title" => title
          }
        } = conn,
        :update
      ) do
    if apikey == api_key() do
      key = "#{type}-#{data}"

      Agent.update(__MODULE__, fn
        %{now_playing: now_playing} ->
          updated_progress = %{
            "type" => type,
            "data" => data,
            "current_time" => current_time,
            "duration" => duration,
            "title" => title,
            "last_seen" => :erlang.monotonic_time(:second)
          }

          updated =
            Map.update(now_playing, key, updated_progress, fn _ -> updated_progress end)
            |> remove_timeout()

          UwUBlogWeb.Endpoint.broadcast("now_playing:lobby", "update", updated)
          %{now_playing: updated}
      end)

      conn
      |> Plug.Conn.send_resp(200, [])
    else
      conn
      |> Plug.Conn.send_resp(401, [])
    end
    |> Plug.Conn.halt()
  end

  def call(%Plug.Conn{} = conn, :fetch) do
    assign(conn, :now_playing, get())
  end

  def call(%Plug.Conn{} = conn, _default) do
    conn
    |> Plug.Conn.send_resp(401, [])
    |> Plug.Conn.halt()
  end

  def get do
    Agent.update(__MODULE__, fn
      %{now_playing: now_playing} ->
        updated = remove_timeout(now_playing)
        %{now_playing: updated}

      _ ->
        %{}
    end)

    Agent.get(__MODULE__, fn
      %{now_playing: now_playing} ->
        now_playing

      _ ->
        %{}
    end)
  end
end
