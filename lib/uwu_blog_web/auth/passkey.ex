defmodule UwUBlogWeb.Auth.Passkey do
  @moduledoc """
  WebAuthn (passkey / security-key) ceremonies for the single admin (Phase 3),
  built on `wax_`.

  Registration runs while the admin is already signed in (bootstrapped off the
  password or Google login); authentication is passwordless from the login page.
  Persistence lives in `UwUBlog.Passkeys`; this module drives the ceremonies and
  translates between the browser's base64url wire format and `wax_`. The `wax_`
  challenge is carried across the two requests in the session.
  """

  alias UwUBlog.Passkeys

  # A stable, opaque WebAuthn user handle for the single admin.
  @user_handle "uwu-blog-admin"

  # ES256 and RS256 — the algorithms essentially every authenticator supports.
  @pub_key_cred_params [
    %{type: "public-key", alg: -7},
    %{type: "public-key", alg: -257}
  ]

  @doc "Whether any passkey is registered (controls showing the login option)."
  defdelegate any?, to: Passkeys

  # --- Registration (admin already signed in) ---

  @doc "Creates a registration challenge to store in the session."
  def registration_challenge do
    Wax.new_registration_challenge(origin: origin(), rp_id: rp_id(), attestation: "none")
  end

  @doc "publicKeyCredentialCreationOptions for `navigator.credentials.create`."
  def creation_options(challenge) do
    %{
      challenge: b64(challenge.bytes),
      rp: %{id: rp_id(), name: rp_name()},
      user: %{id: b64(@user_handle), name: admin_name(), displayName: admin_name()},
      pubKeyCredParams: @pub_key_cred_params,
      authenticatorSelection: %{userVerification: "preferred", residentKey: "preferred"},
      attestation: "none",
      excludeCredentials: credential_descriptors(),
      timeout: 60_000
    }
  end

  @doc """
  Verifies a registration response and stores the new credential under `label`.
  Returns `{:ok, credential}` or `{:error, reason}`.
  """
  def register(credential, challenge, label) do
    with {:ok, attestation_object} <- decode(credential["attestationObject"]),
         {:ok, client_data_json} <- decode(credential["clientDataJSON"]),
         {:ok, {auth_data, _result}} <-
           Wax.register(attestation_object, client_data_json, challenge) do
      acd = auth_data.attested_credential_data

      Passkeys.create_credential(%{
        credential_id: acd.credential_id,
        public_key: :erlang.term_to_binary(acd.credential_public_key),
        aaguid: acd.aaguid,
        sign_count: auth_data.sign_count,
        label: label
      })
    end
  end

  # --- Authentication (passwordless) ---

  @doc "Creates an authentication challenge over all registered credentials."
  def authentication_challenge do
    Wax.new_authentication_challenge(
      origin: origin(),
      rp_id: rp_id(),
      allow_credentials: allow_credentials()
    )
  end

  @doc "publicKeyCredentialRequestOptions for `navigator.credentials.get`."
  def request_options(challenge) do
    %{
      challenge: b64(challenge.bytes),
      rpId: rp_id(),
      allowCredentials: credential_descriptors(),
      userVerification: "preferred",
      timeout: 60_000
    }
  end

  @doc """
  Verifies an authentication assertion, updating the stored sign counter.
  Returns `{:ok, credential}` or `{:error, reason}`.
  """
  def authenticate(credential, challenge) do
    with {:ok, raw_id} <- decode(credential["rawId"]),
         {:ok, auth_data_bin} <- decode(credential["authenticatorData"]),
         {:ok, signature} <- decode(credential["signature"]),
         {:ok, client_data_json} <- decode(credential["clientDataJSON"]),
         %Passkeys.Credential{} = stored <- Passkeys.get_by_credential_id(raw_id),
         {:ok, auth_data} <-
           Wax.authenticate(raw_id, auth_data_bin, signature, client_data_json, challenge) do
      Passkeys.update_sign_count(stored, auth_data.sign_count)
    else
      nil -> {:error, :unknown_credential}
      other -> other
    end
  end

  # --- helpers ---

  defp allow_credentials do
    Enum.map(Passkeys.list_credentials(), fn credential ->
      {credential.credential_id, :erlang.binary_to_term(credential.public_key)}
    end)
  end

  defp credential_descriptors do
    Enum.map(Passkeys.list_credentials(), fn credential ->
      %{type: "public-key", id: b64(credential.credential_id)}
    end)
  end

  defp origin, do: UwUBlogWeb.Endpoint.url()
  defp rp_id, do: URI.parse(origin()).host
  defp rp_name, do: UwUBlog.site_title()
  defp admin_name, do: "admin"

  defp b64(binary), do: Base.url_encode64(binary, padding: false)

  defp decode(value) when is_binary(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode(_value), do: {:error, :missing_field}
end
