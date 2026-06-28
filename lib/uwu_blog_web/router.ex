defmodule UwUBlogWeb.Router do
  use UwUBlogWeb, :router

  import UwUBlogWeb.Auth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {UwUBlogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug :require_admin
  end

  scope "/now-playing", UwUBlogWeb do
    pipe_through :api
    post "/", PageController, :update_track
  end

  scope "/", UwUBlogWeb do
    pipe_through :browser
    get "/", PageController, :index
    get "/about", PageController, :about
    get "/post/:permalink", PageController, :post
    get "/post/:permalink/*assets", PageController, :assets

    live_session :now_playing do
      live "/now_playing", NowPlayingLive.Index
    end
  end

  # Authentication. The controller is mounted on a fixed internal path;
  # `UwUBlogWeb.Plugs.LoginPath` maps the configured public login path onto it.
  scope "/", UwUBlogWeb do
    pipe_through :browser

    get "/__auth/login", AuthController, :new
    post "/__auth/login", AuthController, :create
    delete "/__auth/logout", AuthController, :delete

    get "/auth/google", AuthController, :google_request
    get "/auth/google/callback", AuthController, :google_callback

    post "/auth/passkey/challenge", PasskeyController, :authentication_challenge
    post "/auth/passkey", PasskeyController, :authenticate
  end

  scope "/admin", UwUBlogWeb do
    pipe_through [:browser, :admin]

    get "/", AdminController, :index

    post "/passkeys/challenge", PasskeyController, :registration_challenge
    post "/passkeys", PasskeyController, :register
    delete "/passkeys/:id", PasskeyController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:uwu_blog, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: UwUBlogWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
