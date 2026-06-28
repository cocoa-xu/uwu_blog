defmodule UwUBlogWeb.Auth do
  @moduledoc """
  Single-admin authentication for the blog.

  Sign-in is passwordless: Google OAuth (`UwUBlogWeb.Auth.Google`) and WebAuthn
  passkeys (`UwUBlogWeb.Auth.Passkey`). There is no username/password and no user
  database. The only setting here is `:login_path` — the (optionally secret) path
  the login page is served from.

  Every successful authentication funnels through `log_in_admin/2` (or
  `put_admin_session/1` for the JSON passkey flow); each method only has to
  resolve an allowed identity and then call it.
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
  Marks the current session as the authenticated admin and redirects to the
  admin area. Renews the session id to prevent fixation. This is the single
  choke point every authentication method converges on.
  """
  def log_in_admin(conn, _params \\ %{}) do
    conn
    |> put_admin_session()
    |> redirect(to: signed_in_path())
  end

  @doc """
  Marks the current session as the authenticated admin without redirecting.
  Useful for API-style sign-ins (e.g. the passkey ceremony) that respond with
  JSON and let the client navigate.
  """
  def put_admin_session(conn) do
    conn
    |> renew_session()
    |> put_session(@session_key, true)
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
  `on_mount` hook that gates admin LiveViews. Mirrors `require_admin/2` for the
  socket: it lets authenticated mounts continue and redirects everyone else to
  the login page. Wire it into the admin `live_session`.
  """
  def on_mount(:ensure_admin, _params, session, socket) do
    if session[Atom.to_string(@session_key)] == true do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: login_path())}
    end
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
end
