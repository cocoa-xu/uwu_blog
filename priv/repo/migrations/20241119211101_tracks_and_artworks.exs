defmodule UwUBlog.Repo.Migrations.TracksAndArtworks do
  use Ecto.Migration

  def change do
    create table(:tracks) do
      add :track_id, :string, null: false
      add :source, :string
      add :title, :string
      add :artist, :string
      add :album, :string
      timestamps()
    end

    create unique_index(:tracks, [:track_id])

    create table(:artworks) do
      add :checksum, :string, null: false
      add :public_url, :string
      timestamps()
    end

    create unique_index(:artworks, [:checksum])

    create table(:play_history) do
      add :track_id, :string, null: false
      add :artwork_checksum, :string, null: true
      timestamps()
    end

    create index(:play_history, [:track_id])
    create index(:play_history, [:artwork_checksum])
  end
end
