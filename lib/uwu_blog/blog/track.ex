defmodule UwUBlog.Blog.Track do
  use Ecto.Schema

  import Ecto.Changeset

  alias UwUBlog.Repo

  @type t :: %__MODULE__{}

  schema "tracks" do
    field :track_id, :string
    field :source, :string
    field :title, :string
    field :artist, :string
    field :album, :string

    timestamps()
  end

  def changeset(track, params \\ %{}) do
    track
    |> cast(params, [:source, :title, :artist, :album])
    |> validate_required([:title])
    |> generate_track_id()
  end

  def insert_or_ignore(attrs) do
    track_id = generate_track_id(attrs)

    case Repo.get_by(__MODULE__, track_id: track_id) do
      nil -> Repo.insert!(%__MODULE__{attrs | track_id: track_id})
      track -> track
    end
  end

  def generate_track_id(attrs) do
    source = Map.get(attrs, :source)
    title = Map.get(attrs, :title)
    artist = Map.get(attrs, :artist)
    album = Map.get(attrs, :album)

    Base.encode16(:crypto.hash(:sha256, "#{source}#{title}#{artist}#{album}"), case: :lower)
  end
end
