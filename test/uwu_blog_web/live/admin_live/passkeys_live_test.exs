defmodule UwUBlogWeb.AdminLive.PasskeysTest do
  use UwUBlogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias UwUBlog.Passkeys

  defp credential(id, label) do
    {:ok, credential} =
      Passkeys.create_credential(%{
        credential_id: id,
        public_key: :erlang.term_to_binary(%{1 => 2, 3 => -7}),
        label: label
      })

    credential
  end

  describe "the passkeys page" do
    test "redirects to the login page when unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/admin/passkeys")
    end

    test "lists registered credentials when signed in", %{conn: conn} do
      credential("credential-1", "Nitrokey")

      {:ok, _view, html} = conn |> log_in_admin() |> live("/admin/passkeys")
      assert html =~ "Nitrokey"
    end

    test "removes a credential", %{conn: conn} do
      credential = credential("credential-1", "Nitrokey")

      {:ok, view, _html} = conn |> log_in_admin() |> live("/admin/passkeys")
      assert render(view) =~ "Nitrokey"

      view
      |> element("button[phx-value-id='#{credential.id}']")
      |> render_click()

      refute Passkeys.any?()
      refute render(view) =~ "Nitrokey"
    end
  end
end
