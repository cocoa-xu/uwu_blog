defmodule UwUBlog.Passkeys.Credential do
  @moduledoc """
  A registered WebAuthn (passkey / security-key) credential for the admin.

  `public_key` stores the COSE key as an Erlang term binary; the sign counter is
  used for clone detection on authentication.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "admin_credentials" do
    field :credential_id, :binary
    field :public_key, :binary
    field :sign_count, :integer, default: 0
    field :label, :string
    field :aaguid, :binary

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, [:credential_id, :public_key, :sign_count, :label, :aaguid])
    |> validate_required([:credential_id, :public_key, :label])
    |> validate_length(:label, min: 1, max: 100)
    |> unique_constraint(:credential_id)
  end
end
