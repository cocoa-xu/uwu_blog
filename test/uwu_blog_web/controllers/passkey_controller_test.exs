defmodule UwUBlogWeb.PasskeyControllerTest do
  use UwUBlogWeb.ConnCase, async: true

  alias UwUBlog.Passkeys

  defp credential(id \\ "credential-1") do
    {:ok, credential} =
      Passkeys.create_credential(%{
        credential_id: id,
        public_key: :erlang.term_to_binary(%{1 => 2, 3 => -7}),
        label: "Key"
      })

    credential
  end

  describe "registration challenge (admin only)" do
    test "requires authentication", %{conn: conn} do
      conn = post(conn, "/admin/passkeys/challenge")
      assert redirected_to(conn) == "/login"
    end

    test "returns creation options and stores the challenge when signed in", %{conn: conn} do
      conn = conn |> log_in_admin() |> post("/admin/passkeys/challenge")

      options = json_response(conn, 200)
      assert is_binary(options["challenge"])
      assert options["rp"]["id"]
      assert options["user"]["id"]
      assert get_session(conn, :passkey_registration_challenge)
    end
  end

  describe "the login page" do
    test "offers passkey sign-in only once a credential is registered", %{conn: conn} do
      refute html_response(get(conn, "/login"), 200) =~ "Sign in with a passkey"

      credential()
      assert html_response(get(conn, "/login"), 200) =~ "Sign in with a passkey"
    end
  end

  describe "authentication challenge (public)" do
    test "returns request options and stores the challenge", %{conn: conn} do
      conn = post(conn, "/auth/passkey/challenge")

      options = json_response(conn, 200)
      assert is_binary(options["challenge"])
      assert options["rpId"]
      assert get_session(conn, :passkey_authentication_challenge)
    end
  end

  describe "removing a credential" do
    test "deletes it when signed in", %{conn: conn} do
      credential = credential()
      conn = conn |> log_in_admin() |> delete("/admin/passkeys/#{credential.id}")
      assert redirected_to(conn) == "/admin"
      refute Passkeys.any?()
    end

    test "requires authentication", %{conn: conn} do
      credential = credential()
      conn = delete(conn, "/admin/passkeys/#{credential.id}")
      assert redirected_to(conn) == "/login"
      assert Passkeys.any?()
    end
  end
end
