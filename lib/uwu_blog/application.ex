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

    install_log_redaction()

    # Go distributed before DNSCluster starts, so it derives the right basename.
    UwUBlog.Distribution.ensure_started()

    children =
      [
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
        {UwUBlog.PostCollection, name: UwUBlog.PostCollection}
      ] ++ now_playing_children() ++ node_network_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UwUBlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # The now-playing worker polls the database at boot. It is disabled in test
  # (config :uwu_blog, :start_now_playing, false) so it doesn't crash-loop
  # against the SQL sandbox, which has no connection owner during app boot.
  defp now_playing_children do
    if Application.get_env(:uwu_blog, :start_now_playing, true) do
      [{UwUBlog.NowPlaying, name: UwUBlog.NowPlaying}]
    else
      []
    end
  end

  # Each node looks up its own public egress IP/ASN for the cluster dashboard.
  # The Task.Supervisor runs the lookups off the GenServer; disabled in test so
  # the suite never reaches the network (config :uwu_blog, :start_node_network).
  defp node_network_children do
    if Application.get_env(:uwu_blog, :start_node_network, true) do
      [{Task.Supervisor, name: UwUBlog.TaskSupervisor}, UwUBlog.NodeNetwork]
    else
      []
    end
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

  # Redact configured secrets from every log event before any handler (console,
  # Sentry) sees them. Only installed when there is something to redact.
  defp install_log_redaction do
    case UwUBlog.Secrets.values() do
      [] ->
        :ok

      secrets ->
        _ =
          :logger.add_primary_filter(
            :uwu_blog_redact_secrets,
            {&UwUBlog.LogRedactor.filter/2, secrets}
          )

        :ok
    end
  end
end
