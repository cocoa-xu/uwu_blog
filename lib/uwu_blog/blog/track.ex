defmodule UwUBlog.Blog.Track do
  use Ecto.Schema

  import Ecto.Query

  import Ecto.Changeset

  alias UwUBlog.Repo
  alias UwUBlog.Blog.Artwork

  @type t :: %__MODULE__{}

  @primary_key {:id, :id, autogenerate: true}
  schema "tracks" do
    field :source, :string
    field :title, :string
    field :artist, :string
    field :album, :string

    has_one :artwork, Artwork, on_replace: :update

    timestamps()
  end

  def changeset(track, params \\ %{}) do
    fields = [:source, :title, :artist, :album]

    track
    |> cast(params, fields)
    |> validate_required([:title])
  end

  def same_track?(a, b) do
    a.source == b.source and a.title == b.title and a.artist == b.artist and a.album == b.album
  end

  def update_now_playing(track) do
    last = get_most_recent_tracks(1)

    if Enum.count(last) == 0 do
      %{track: Repo.insert!(track), play_history_changed: false}
    else
      last = hd(last)

      if same_track?(last, track) do
        %{track: last, play_history_changed: false}
      else
        %{track: Repo.insert!(track), play_history_changed: true}
      end
    end
  end

  @spec get_most_recent_tracks(integer) :: [t()]
  def get_most_recent_tracks(number) do
    Repo.all(
      from t in __MODULE__,
        order_by: [desc: t.inserted_at],
        limit: ^number
    )
    |> Repo.preload(:artwork)
  end
end
