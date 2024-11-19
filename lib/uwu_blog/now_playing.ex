defmodule UwUBlog.NowPlaying do
  @moduledoc false

  use GenServer
  use UwUBlog.Tracing.Decorator

  alias UwUBlog.Blog.Artwork
  alias UwUBlog.Blog.Track
  alias UwUBlog.Blog.PlayHistory

  require Logger

  defstruct [
    :now_playing,
    :play_history,
    :number_of_tracks,
    :expecting_checksum
  ]

  @type t :: %__MODULE__{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @decorate trace()
  def get_tracks(pid \\ __MODULE__) do
    GenServer.call(pid, :get_tracks)
  end

  def update_track(pid \\ __MODULE__, params)

  def update_track(pid, %{
        "apikey" => apikey,
        "type" => "artwork",
        "artwork_data" => data,
        "artwork_checksum" => checksum,
        "artwork_type" => type
      }) do
    if Plug.Crypto.secure_compare(apikey, api_key()) do
      GenServer.call(pid, {:update_artwork, data, checksum, type})
    else
      Logger.error("Invalid API key")
      {403, %{error: "Nah"}}
    end
  end

  def update_track(
        pid,
        %{"apikey" => apikey, "type" => "track", "artwork_checksum" => checksum} = params
      )
      when is_binary(checksum) do
    if Plug.Crypto.secure_compare(apikey, api_key()) do
      GenServer.call(pid, {:update_track, params})
    else
      {403, %{error: "Nah"}}
    end
  end

  def update_track(_pid, _params) do
    Logger.error("Unknown update_track params")
    {403, %{error: "Nah"}}
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    state = %__MODULE__{
      now_playing: nil,
      play_history: [],
      number_of_tracks: opts[:number_of_tracks] || 30,
      expecting_checksum: nil
    }

    {:ok, state, {:continue, :load_tracks}}
  end

  @impl GenServer
  def handle_continue(:load_tracks, state) do
    {:noreply, reload(state)}
  end

  @impl GenServer
  @decorate trace()
  def handle_info(:reload, state) do
    {:noreply, reload(state)}
  end

  @impl GenServer
  @decorate trace()
  def handle_call(:get_tracks, _from, state) do
    now_playing =
      if now_playing = state.now_playing do
        current_track =
          now_playing.track
          |> Map.put(:currentPlaying?, true)
          |> Map.put(:position, now_playing.position)
          |> Map.put(:duration, now_playing.duration)

        %{track: current_track, artwork: now_playing.artwork}
      end

    {:reply, %{now_playing: now_playing, play_history: state.play_history}, state}
  end

  @decorate trace()
  def handle_call({:update_track, params}, _from, state) do
    track = %Track{
      source: params["source"],
      title: params["title"],
      artist: params["artist"],
      album: params["album"]
    }

    track = Track.insert_or_ignore(track)

    artwork_checksum = params["artwork_checksum"]
    artwork = Artwork.get_artwork(artwork_checksum)

    result = PlayHistory.update_now_playing(track, artwork)

    state =
      if result.updated? do
        reload(state)
      else
        state
      end

    resp = {200, %{has_artwork: not is_nil(artwork) || artwork_checksum == "no_artwork"}}

    Phoenix.PubSub.broadcast(
      UwUBlog.PubSub,
      "now_playing",
      :now_playing_changed
    )

    {:reply, resp,
     %{
       state
       | now_playing: %{
           track: track,
           artwork: artwork,
           duration: params["duration"],
           position: params["position"]
         },
         expecting_checksum: artwork_checksum
     }}
  end

  def handle_call(
        {:update_artwork, data, checksum, type},
        _from,
        state = %{expecting_checksum: checksum}
      ) do
    case Artwork.update_artwork(data, checksum, type) do
      {:ok, artwork} ->
        track = state.now_playing.track
        result = PlayHistory.update_now_playing(track, artwork)

        state =
          if result.updated? do
            reload(state)
          else
            state
          end

        now_playing = %{state.now_playing | artwork: artwork}

        Phoenix.PubSub.broadcast(
          UwUBlog.PubSub,
          "now_playing",
          :now_playing_changed
        )

        {:reply, {200, %{artwork_updated: true}}, %{state | now_playing: now_playing}}

      {:error, reason} when is_binary(reason) ->
        {:reply, {403, %{error: reason}}, state}

      {:error, e} ->
        Logger.error("Unknown error when updating artwork: #{inspect(e)}")
        {:reply, {403, %{error: "Unknown error when updating artwork"}}, state}
    end
  end

  def handle_call({:update_artwork, _data, _checksum, _type}, _from, state) do
    {:reply, {403, %{error: "Not the expected checksum"}}, state}
  end

  @decorate trace()
  defp reload(state) do
    %{state | play_history: load_history(state.number_of_tracks)}
  end

  @decorate trace()
  defp load_history(number_of_records) do
    Logger.info("Loading most recent #{number_of_records} play history records")
    PlayHistory.load_history(number_of_records)
  end

  defp api_key, do: Application.get_env(:uwu_blog, __MODULE__)[:apikey]
end
