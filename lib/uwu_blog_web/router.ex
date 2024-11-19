defmodule UwUBlogWeb.Router do
  use UwUBlogWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {UwUBlogWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
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
