defmodule UwUBlog.Blog.PlayHistory do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query
  alias UwUBlog.Blog.Artwork
  alias UwUBlog.Repo

  alias UwUBlog.Blog.Track

  schema "play_history" do
    field :track_id, :string
    field :artwork_checksum, :string

    timestamps()
  end

  def changeset(play_history, attrs) do
    play_history
    |> cast(attrs, [:track_id, :artwork_checksum])
    |> validate_required([:track_id])
  end

  def update_now_playing(%Track{track_id: track_id}, nil) do
    last =
      if last = Repo.all(from p in __MODULE__, order_by: [desc: p.inserted_at], limit: 1) do
        last = hd(last)

        if last.track_id == track_id do
          last
        end
      end

    if is_nil(last) do
      record =
        Repo.insert!(%__MODULE__{
          track_id: track_id,
          artwork_checksum: nil
        })

      %{updated?: true, record: record}
    else
      %{updated?: false, record: last}
    end
  end

  def update_now_playing(%Track{track_id: track_id}, %Artwork{checksum: artwork_checksum}) do
    last =
      if last = Repo.all(from p in __MODULE__, order_by: [desc: p.inserted_at], limit: 1) do
        last = hd(last)

        if last.track_id == track_id and last.artwork_checksum == artwork_checksum do
          last
        end
      end

    if is_nil(last) do
      record =
        Repo.insert!(%__MODULE__{
          track_id: track_id,
          artwork_checksum: artwork_checksum
        })

      %{updated?: true, record: record}
    else
      %{updated?: false, record: last}
    end
  end

  def load_history(number) do
    Repo.all(
      from p in __MODULE__,
        order_by: [desc: p.inserted_at],
        limit: ^number
    )
  end
end
