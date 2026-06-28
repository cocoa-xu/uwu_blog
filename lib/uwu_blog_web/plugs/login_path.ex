defmodule UwUBlogWeb.Plugs.LoginPath do
  @moduledoc """
  Resolves the runtime-configurable login path.

  Phoenix routes are compiled, so a literal `get "/login"` cannot read a value
  set in `config/runtime.exs` (and `Application.compile_env` would raise on a
  runtime mismatch). Instead the auth controller is mounted on a fixed internal
  path and this plug — running before the router — rewrites requests for the
  configured public login path onto it. Direct hits on the internal path are
  rejected so the configured path stays the only public entry.
  """

  @behaviour Plug

  import Plug.Conn

  @canonical_path_info ~w(__auth login)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: @canonical_path_info} = conn, _opts) do
    conn |> send_resp(:not_found, "Not Found") |> halt()
  end

  def call(conn, _opts) do
    if conn.request_path == UwUBlogWeb.Auth.login_path() do
      %{conn | path_info: @canonical_path_info}
    else
      conn
    end
  end
end
