defmodule UwUBlogWeb.LiveAcceptance do
  @moduledoc """
  `on_mount` hook that lets a connected LiveView share the test's
  `Ecto.Adapters.SQL.Sandbox` connection, so concurrent LiveView tests can hit
  the database. It is only wired into LiveViews when the `:sql_sandbox` flag is
  set (test env) — see `UwUBlogWeb.live_view/0` — and is a no-op everywhere else.
  """

  import Phoenix.Component, only: [assign_new: 3]
  import Phoenix.LiveView, only: [connected?: 1, get_connect_info: 2]

  def on_mount(:default, _params, _session, socket) do
    %{assigns: %{phoenix_ecto_sandbox: metadata}} =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)

    {:cont, socket}
  end
end
