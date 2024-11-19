defmodule UwUBlog.Repo.Migrations.Tracks do
  use Ecto.Migration

  def change do
    create table(:tracks) do
      add :source, :string, default: "unknown"
      add :title, :string
      add :artist, :string, default: ""
      add :album, :string, default: ""

      timestamps()
    end
  end
end
