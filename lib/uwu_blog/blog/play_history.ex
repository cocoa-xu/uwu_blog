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
    case Repo.all(from p in __MODULE__, order_by: [desc: p.inserted_at], limit: 1) do
      [%{track_id: ^track_id} = last | _] ->
        %{updated?: false, record: last}

      _ ->
        record =
          Repo.insert!(%__MODULE__{
            track_id: track_id,
            artwork_checksum: nil
          })

        %{updated?: true, record: record}
    end
  end

  def update_now_playing(%Track{track_id: track_id}, %Artwork{checksum: artwork_checksum}) do
    case Repo.all(from p in __MODULE__, order_by: [desc: p.inserted_at], limit: 1) do
      [%__MODULE__{track_id: ^track_id, artwork_checksum: current_checksum} = last | _] ->
        cond do
          is_nil(current_checksum) ->
            last = Repo.update!(changeset(last, %{artwork_checksum: artwork_checksum}))
            %{updated?: true, record: last}

          current_checksum != artwork_checksum ->
            last =
              Repo.insert!(%__MODULE__{
                track_id: track_id,
                artwork_checksum: artwork_checksum
              })

            %{updated?: true, record: last}

          true ->
            %{updated?: false, record: last}
        end

      _ ->
        record =
          Repo.insert!(%__MODULE__{
            track_id: track_id,
            artwork_checksum: artwork_checksum
          })

        %{updated?: true, record: record}
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
