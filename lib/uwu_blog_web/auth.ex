defmodule UwUBlogWeb.Auth do
  @moduledoc """
  Single-admin authentication for the blog.

  Phase 1 verifies one owner account against credentials supplied through
  application config under `config :uwu_blog, #{inspect(__MODULE__)}`: hardcoded
  in `config/dev.exs` for development and read from the environment in
  `config/runtime.exs` for production. There is no database and no registration.

  Every successful authentication funnels through `log_in_admin/2`. That is the
  single seam future strategies (OAuth, WebAuthn/passkeys) hook into: each one
  only has to resolve an allowed identity and then call `log_in_admin/2`.
  """

  use UwUBlogWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  @session_key :admin_authenticated

  @doc """
  The configured public login path. Defaults to `/login` when unset so the
  feature works out of the box in development.
  """
  def login_path do
    config(:login_path) || "/login"
  end

  @doc """
  Verifies a username/password pair against the configured credentials with a
  constant-time comparison. Fails closed when either credential is unconfigured,
  so an unconfigured production deploy simply rejects every login.
  """
  def valid_credentials?(username, password)
      when is_binary(username) and is_binary(password) do
    secure_equal?(config(:username), username) and
      secure_equal?(config(:password), password)
  end

  def valid_credentials?(_username, _password), do: false

  @doc """
  Marks the current session as the authenticated admin and redirects to the
  admin area. Renews the session id to prevent fixation. This is the single
  choke point every authentication method converges on.
  """
  def log_in_admin(conn, _params \\ %{}) do
    conn
    |> renew_session()
    |> put_session(@session_key, true)
    |> redirect(to: signed_in_path())
  end

  @doc "Clears the admin session and redirects to the login page."
  def log_out_admin(conn) do
    conn
    |> renew_session()
    |> configure_session(drop: true)
    |> redirect(to: login_path())
  end

  @doc """
  Plug that assigns `:current_admin?` from the session so any page (e.g. the
  nav) can branch on authentication state.
  """
  def fetch_current_admin(conn, _opts) do
    assign(conn, :current_admin?, admin?(conn))
  end

  @doc """
  Plug that halts unauthenticated requests, redirecting them to the login page.
  Use it to gate admin-only routes.
  """
  def require_admin(conn, _opts) do
    if admin?(conn) do
      conn
    else
      conn
      |> put_flash(:error, "Please sign in to continue.")
      |> redirect(to: login_path())
      |> halt()
    end
  end

  @doc "Plug that redirects already-authenticated admins away from the login page."
  def redirect_if_admin(conn, _opts) do
    if admin?(conn) do
      conn
      |> redirect(to: signed_in_path())
      |> halt()
    else
      conn
    end
  end

  defp admin?(conn), do: get_session(conn, @session_key) == true

  defp signed_in_path, do: ~p"/admin"

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp config(key), do: Application.get_env(:uwu_blog, __MODULE__, [])[key]

  defp secure_equal?(expected, given)
       when is_binary(expected) and expected != "" and is_binary(given) do
    Plug.Crypto.secure_compare(expected, given)
  end

  defp secure_equal?(_expected, _given), do: false
end
