defmodule UwUBlog.Repo.Migrations.CreateAdminCredentials do
  use Ecto.Migration

  def change do
    create table(:admin_credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :bigint, null: false, default: 0
      add :label, :string, null: false
      add :aaguid, :binary

      timestamps(type: :utc_datetime)
    end

    create unique_index(:admin_credentials, [:credential_id])
  end
end
