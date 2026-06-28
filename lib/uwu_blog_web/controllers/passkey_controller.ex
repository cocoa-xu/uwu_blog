defmodule UwUBlogWeb.PasskeyController do
  use UwUBlogWeb, :controller

  import UwUBlogWeb.Auth

  alias UwUBlogWeb.Auth.Passkey

  # --- Registration (admin only) ---

  def registration_challenge(conn, _params) do
    challenge = Passkey.registration_challenge()

    conn
    |> put_session(:passkey_registration_challenge, challenge)
    |> json(Passkey.creation_options(challenge))
  end

  def register(conn, %{"credential" => credential} = params) do
    challenge = get_session(conn, :passkey_registration_challenge)
    conn = delete_session(conn, :passkey_registration_challenge)

    case challenge && Passkey.register(credential, challenge, label(params)) do
      {:ok, _credential} ->
        json(conn, %{ok: true})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{ok: false})
    end
  end

  # --- Authentication (passwordless) ---

  def authentication_challenge(conn, _params) do
    challenge = Passkey.authentication_challenge()

    conn
    |> put_session(:passkey_authentication_challenge, challenge)
    |> json(Passkey.request_options(challenge))
  end

  def authenticate(conn, %{"credential" => credential}) do
    challenge = get_session(conn, :passkey_authentication_challenge)
    conn = delete_session(conn, :passkey_authentication_challenge)

    case challenge && Passkey.authenticate(credential, challenge) do
      {:ok, _credential} ->
        conn
        |> put_admin_session()
        |> json(%{ok: true, redirect: ~p"/admin"})

      _ ->
        conn |> put_status(:unauthorized) |> json(%{ok: false})
    end
  end

  defp label(params) do
    case params |> Map.get("label", "") |> to_string() |> String.trim() do
      "" -> "Passkey"
      label -> label
    end
  end
end
