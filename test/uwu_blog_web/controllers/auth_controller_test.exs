defmodule UwUBlogWeb.AuthControllerTest do
  use UwUBlogWeb.ConnCase, async: true

  describe "the login page" do
    test "renders the passwordless sign-in options", %{conn: conn} do
      response = html_response(get(conn, "/login"), 200)
      assert response =~ "sign in"
      assert response =~ "Sign in with Google"
      refute response =~ ~s(name="auth[password]")
    end

    test "rejects the internal canonical path, keeping the configured path the only entry",
         %{conn: conn} do
      conn = get(conn, "/__auth/login")
      assert response(conn, 404)
    end

    test "an authenticated admin visiting the login page is redirected to /admin", %{conn: conn} do
      conn = conn |> log_in_admin() |> get("/login")
      assert redirected_to(conn) == "/admin"
    end
  end

  describe "the admin area" do
    test "redirects to the login page when unauthenticated", %{conn: conn} do
      conn = get(conn, "/admin")
      assert redirected_to(conn) == "/login"
    end

    test "is reachable once signed in", %{conn: conn} do
      conn = conn |> log_in_admin() |> get("/admin")
      assert html_response(conn, 200) =~ "signed in"
    end
  end

  describe "signing out" do
    test "clears the session and redirects to the login page", %{conn: conn} do
      conn = conn |> log_in_admin() |> delete("/__auth/logout")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end
  end

  describe "signing in with Google" do
    test "redirects to Google's consent screen with a CSRF state", %{conn: conn} do
      conn = get(conn, "/auth/google")
      location = redirected_to(conn)
      assert location =~ "accounts.google.com"
      assert location =~ "test-client-id"
      assert get_session(conn, :google_oauth_state)
    end

    test "an allowed, verified Google account signs in", %{conn: conn} do
      stub_google("admin@example.com", true)
      conn = get(conn, "/auth/google")
      state = get_session(conn, :google_oauth_state)

      conn = get(conn, "/auth/google/callback?code=good&state=#{state}")
      assert redirected_to(conn) == "/admin"
      assert get_session(conn, :admin_authenticated) == true
    end

    test "a Google account outside the allow-list is rejected", %{conn: conn} do
      stub_google("stranger@example.com", true)
      conn = get(conn, "/auth/google")
      state = get_session(conn, :google_oauth_state)

      conn = get(conn, "/auth/google/callback?code=good&state=#{state}")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end

    test "an unverified Google email is rejected", %{conn: conn} do
      stub_google("admin@example.com", false)
      conn = get(conn, "/auth/google")
      state = get_session(conn, :google_oauth_state)

      conn = get(conn, "/auth/google/callback?code=good&state=#{state}")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end

    test "a mismatched state is rejected (CSRF protection)", %{conn: conn} do
      conn = get(conn, "/auth/google")
      conn = get(conn, "/auth/google/callback?code=good&state=forged")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end

    test "a denied consent returns to the login page", %{conn: conn} do
      conn = get(conn, "/auth/google/callback?error=access_denied")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end
  end

  defp stub_google(email, verified) do
    Req.Test.stub(UwUBlogWeb.Auth.Google, fn conn ->
      case conn.request_path do
        "/token" -> Req.Test.json(conn, %{"access_token" => "test-access-token"})
        "/v1/userinfo" -> Req.Test.json(conn, %{"email" => email, "email_verified" => verified})
      end
    end)
  end
end
