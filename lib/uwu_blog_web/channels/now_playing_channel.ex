defmodule UwUBlogWeb.NowPlayingChannel do
  use UwUBlogWeb, :channel

  @impl true
  def join("now_playing:lobby", _payload, socket) do
    {:ok, socket}
  end

  def join("now_playing:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
