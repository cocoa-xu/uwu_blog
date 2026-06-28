defmodule UwUBlogWeb.AuthController do
  use UwUBlogWeb, :controller

  import UwUBlogWeb.Auth

  alias UwUBlogWeb.Auth.Google
  alias UwUBlogWeb.Auth.Passkey

  plug :redirect_if_admin when action in [:new, :create, :google_request]

  def new(conn, _params) do
    render_login(conn, %{})
  end

  def create(conn, %{"auth" => %{"username" => username, "password" => password}})
      when is_binary(username) and is_binary(password) do
    if valid_credentials?(username, password) do
      conn
      |> put_flash(:info, "Welcome back.")
      |> log_in_admin()
    else
      conn
      |> put_flash(:error, "Invalid username or password.")
      |> put_status(:unauthorized)
      |> render_login(%{"username" => username})
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Invalid username or password.")
    |> put_status(:unauthorized)
    |> render_login(%{})
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been signed out.")
    |> log_out_admin()
  end

  def google_request(conn, _params) do
    if Google.configured?() do
      state = generate_state()

      conn
      |> put_session(:google_oauth_state, state)
      |> redirect(external: Google.authorize_url(state))
    else
      conn
      |> put_flash(:error, "Google sign-in is not configured.")
      |> redirect(to: login_path())
    end
  end

  def google_callback(conn, %{"error" => _reason}) do
    conn
    |> put_flash(:error, "Google sign-in was cancelled.")
    |> redirect(to: login_path())
  end

  def google_callback(conn, %{"code" => code, "state" => state}) when is_binary(code) do
    if valid_state?(conn, state) do
      conn
      |> delete_session(:google_oauth_state)
      |> sign_in_with_google(code)
    else
      conn
      |> put_flash(:error, "Invalid sign-in attempt. Please try again.")
      |> redirect(to: login_path())
    end
  end

  def google_callback(conn, _params) do
    conn
    |> put_flash(:error, "Could not sign you in with Google.")
    |> redirect(to: login_path())
  end

  defp sign_in_with_google(conn, code) do
    with {:ok, email} <- Google.fetch_email(code),
         true <- Google.allowed?(email) do
      conn
      |> put_flash(:info, "Welcome back.")
      |> log_in_admin()
    else
      false ->
        conn
        |> put_flash(:error, "That Google account is not allowed.")
        |> redirect(to: login_path())

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not sign you in with Google.")
        |> redirect(to: login_path())
    end
  end

  defp generate_state, do: 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp valid_state?(conn, state) when is_binary(state) do
    case get_session(conn, :google_oauth_state) do
      nil -> false
      stored -> Plug.Crypto.secure_compare(stored, state)
    end
  end

  defp valid_state?(_conn, _state), do: false

  defp render_login(conn, params) do
    conn
    |> assign(:login_path, login_path())
    |> assign(:google_enabled, Google.configured?())
    |> assign(:passkey_enabled, Passkey.any?())
    |> assign(:form, Phoenix.Component.to_form(params, as: :auth))
    |> render(:new)
  end
end
