defmodule UwUBlogWeb.AdminLive.Passkeys do
  @moduledoc """
  Admin page for managing WebAuthn passkeys. Registration runs the browser
  credential ceremony through the `PasskeyRegister` JS hook (which posts to
  `UwUBlogWeb.PasskeyController`); this view lists and removes credentials.
  """
  use UwUBlogWeb, :admin_live_view

  alias UwUBlog.Passkeys

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page, :passkeys) |> load_credentials()}
  end

  @impl true
  def handle_event("passkey_registered", _params, socket) do
    {:noreply, socket |> put_flash(:info, "Passkey registered.") |> load_credentials()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    id |> Passkeys.get_credential!() |> Passkeys.delete_credential()
    {:noreply, socket |> put_flash(:info, "Passkey removed.") |> load_credentials()}
  end

  defp load_credentials(socket) do
    assign(socket, :credentials, Passkeys.list_credentials())
  end
end
