defmodule UwUBlog.Passkeys do
  @moduledoc """
  Storage for the admin's registered WebAuthn (passkey) credentials.

  There is a single admin, so credentials are not scoped to a user — any stored
  credential authenticates the admin. The WebAuthn ceremonies themselves live in
  `UwUBlogWeb.Auth.Passkey`; this module only persists what they produce.
  """

  import Ecto.Query

  alias UwUBlog.Passkeys.Credential
  alias UwUBlog.Repo

  @doc "All registered credentials, oldest first."
  def list_credentials do
    Repo.all(from c in Credential, order_by: [asc: c.inserted_at])
  end

  @doc "Whether any credential is registered (used to show the passkey login option)."
  def any? do
    Repo.exists?(Credential)
  end

  @doc "Looks up a credential by its raw WebAuthn credential id."
  def get_by_credential_id(credential_id) when is_binary(credential_id) do
    Repo.get_by(Credential, credential_id: credential_id)
  end

  @doc "Fetches a credential by primary key, raising if it is missing."
  def get_credential!(id), do: Repo.get!(Credential, id)

  @doc "Persists a newly registered credential."
  def create_credential(attrs) do
    %Credential{}
    |> Credential.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates the stored sign counter after a successful authentication."
  def update_sign_count(%Credential{} = credential, sign_count) do
    credential
    |> Credential.changeset(%{sign_count: sign_count})
    |> Repo.update()
  end

  @doc "Removes a registered credential."
  def delete_credential(%Credential{} = credential), do: Repo.delete(credential)
end
