defmodule UwUBlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:my_sentry_handler, Sentry.LoggerHandler, %{
      config: %{metadata: [:file, :line]}
    })

    :ok = start_otel()

    children = [
      UwUBlogWeb.Telemetry,
      UwUBlog.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:uwu_blog, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:uwu_blog, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: UwUBlog.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FaviconCafe.Finch},
      # Start a worker by calling: FaviconCafe.Worker.start_link(arg)
      # {FaviconCafe.Worker, arg},
      # Start to serve requests, typically the last entry
      UwUBlogWeb.Endpoint,
      UwUBlog.Post,
      UwUBlogWeb.Plugs.NowPlaying
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UwUBlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec start_otel() :: :ok
  def start_otel do
    OpentelemetryEcto.setup([:uwu_blog, :repo], db_statement: :enabled)
    :opentelemetry_cowboy.setup()
    OpentelemetryPhoenix.setup(adapter: :cowboy2)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UwUBlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end
end
