defmodule UwUBlog.Repo.Migrations.Artworks do
  use Ecto.Migration

  def change do
    create table(:artworks) do
      add :public_url, :string
      add :checksum, :string
      add :track_id, :id

      timestamps()
    end

    create unique_index(:artworks, [:checksum])
  end
end
