defmodule UwUBlogWeb.NowPlayingSocket do
  use Phoenix.Socket

  channel "now_playing:*", UwUBlogWeb.NowPlayingChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
