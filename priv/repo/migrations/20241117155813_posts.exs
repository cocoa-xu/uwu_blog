defmodule UwUBlog.Repo.Migrations.Posts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :liveview?, :boolean
      add :content, :string
      add :permalink, :string
      add :checksum, :string

      timestamps()
    end

    create unique_index(:posts, [:permalink])
  end
end
