defmodule UwUBlog.Repo.Migrations.Assets do
  use Ecto.Migration

  def change do
    create table(:assets) do
      add :type, :string
      add :key, :string
      add :public_url, :string
      add :mtime, :utc_datetime_usec
      add :checksum, :string

      timestamps()
    end

    create unique_index(:assets, [:key])
  end
end
