defmodule UwUBlogWeb.NowPlayingLive.Index do
  @moduledoc false
  use UwUBlogWeb, :live_view

  alias UwUBlog.NowPlaying

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(UwUBlog.PubSub, "now_playing")
    end

    %{now_playing: now_playing, play_history: play_history} = NowPlaying.get_tracks()
    play_history = if Enum.count(play_history) > 0, do: tl(play_history), else: play_history

    {:ok,
     socket
     |> assign(:now_playing, cast(now_playing))
     |> assign(:play_history, Enum.map(play_history, &cast/1))}
  end

  def cast(nil), do: nil

  def cast(track) do
    artwork =
      if track.artwork do
        track.artwork.public_url
      else
        "/assets/artwork.jpg"
      end

    track
    |> Map.from_struct()
    |> Map.put(:currentPlaying?, Map.get(track, :currentPlaying?, false))
    |> Map.put(:arkwork_url, artwork)
  end

  @impl Phoenix.LiveView
  @spec handle_params(any(), any(), any()) :: {:noreply, any()}
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(:now_playing_changed, socket) do
    %{now_playing: now_playing, play_history: play_history} = NowPlaying.get_tracks()
    play_history = if Enum.count(play_history) > 0, do: tl(play_history), else: play_history

    {:noreply,
     socket
     |> assign(:now_playing, cast(now_playing))
     |> assign(:play_history, Enum.map(play_history, &cast/1))}
  end

  def now_playing_card(assigns) do
    ~H"""
    <div>
      <div class={
        ["bg-[#FFF5F5] bg-opacity-35 px-8 pt-8 rounded-lg shadow-sm w-80", (if @item.currentPlaying?, do: "pb-4", else: "pb-10")]
      }>
      <img src={@item.arkwork_url} class="w-64 h-64 mx-auto rounded-lg mb-4 shadow-lg shadow-pink-50" alt={@item.title}>
      <h2 class={
        ["text-xl font-semibold text-center", (if @item.currentPlaying?, do: "", else: "pt-6")]
      }><%= @item.title %></h2>
      <p class="text-gray-600 text-md text-center"><%= @item.artist %></p>
      <p class="text-gray-600 text-sm text-center"><%= @item.album %></p>
      <%= if @item.currentPlaying? do %>
        <div class="mt-4 bg-gray-200 h-1 rounded-full">
          <div class="bg-pink-500 h-1 rounded-full" style={"width: #{ trunc(@item.position/@item.duration*100) }%"}></div>
        </div>
        <div class="flex justify-between mt-2 text-sm text-gray-600">
          <span><%= format_time(@item.position) %></span>
          <span><%= format_time(@item.duration) %></span>
        </div>
      <% end %>
      </div>
    </div>
    """
  end

  def format_time(time) when time < 60 * 60 do
    String.slice(Time.to_string(Time.add(~T[00:00:00], trunc(time))), 3..-1//1)
  end

  def format_time(time) do
    Time.to_string(Time.add(~T[00:00:00], trunc(time)))
  end
end
