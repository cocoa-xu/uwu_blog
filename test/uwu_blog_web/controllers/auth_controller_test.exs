defmodule UwUBlogWeb.AuthControllerTest do
  use UwUBlogWeb.ConnCase, async: true

  @username "testadmin"
  @password "testpass"

  defp valid_params, do: %{"auth" => %{"username" => @username, "password" => @password}}

  describe "the login page" do
    test "renders the sign-in form at the configured login path", %{conn: conn} do
      conn = get(conn, "/login")
      response = html_response(conn, 200)
      assert response =~ "sign in"
      assert response =~ ~s(name="auth[username]")
      assert response =~ ~s(name="auth[password]")
    end

    test "rejects the internal canonical path, keeping the configured path the only entry",
         %{conn: conn} do
      conn = get(conn, "/__auth/login")
      assert response(conn, 404)
    end
  end

  describe "signing in" do
    test "valid credentials authenticate the admin and redirect to /admin", %{conn: conn} do
      conn = post(conn, "/login", valid_params())
      assert redirected_to(conn) == "/admin"
      assert get_session(conn, :admin_authenticated) == true
    end

    test "invalid credentials are rejected with 401 and no session", %{conn: conn} do
      conn = post(conn, "/login", %{"auth" => %{"username" => @username, "password" => "nope"}})
      assert html_response(conn, 401) =~ "Invalid username or password"
      refute get_session(conn, :admin_authenticated)
    end

    test "missing params are rejected", %{conn: conn} do
      conn = post(conn, "/login", %{})
      assert html_response(conn, 401) =~ "Invalid username or password"
      refute get_session(conn, :admin_authenticated)
    end

    test "an authenticated admin visiting the login page is redirected to /admin", %{conn: conn} do
      conn = conn |> post("/login", valid_params()) |> get("/login")
      assert redirected_to(conn) == "/admin"
    end
  end

  describe "the admin area" do
    test "redirects to the login page when unauthenticated", %{conn: conn} do
      conn = get(conn, "/admin")
      assert redirected_to(conn) == "/login"
    end

    test "is reachable once signed in", %{conn: conn} do
      conn = conn |> post("/login", valid_params()) |> get("/admin")
      assert html_response(conn, 200) =~ "signed in"
    end
  end

  describe "signing out" do
    test "clears the session and redirects to the login page", %{conn: conn} do
      conn = post(conn, "/login", valid_params())
      assert get_session(conn, :admin_authenticated) == true

      conn = delete(conn, "/__auth/logout")
      assert redirected_to(conn) == "/login"
      refute get_session(conn, :admin_authenticated)
    end
  end

  describe "signing in with Google" do
    test "the login page shows the Google button", %{conn: conn} do
      assert html_response(get(conn, "/login"), 200) =~ "Sign in with Google"
    end

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
