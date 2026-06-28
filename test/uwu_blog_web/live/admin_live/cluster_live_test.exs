defmodule UwUBlogWeb.AdminLive.ClusterTest do
  use UwUBlogWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "the cluster dashboard" do
    test "redirects to the login page when unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/admin")
    end

    test "renders cluster and runtime stats when signed in", %{conn: conn} do
      {:ok, _view, html} = conn |> log_in_admin() |> live("/admin")

      assert html =~ "cluster"
      assert html =~ to_string(Node.self())
      assert html =~ System.version()
    end
  end
end
