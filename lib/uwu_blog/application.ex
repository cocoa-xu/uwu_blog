defmodule UwUBlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      UwUBlog.Repo,
      # Start the Telemetry supervisor
      UwUBlogWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: UwUBlog.PubSub},
      # Start the Endpoint (http/https)
      UwUBlogWeb.Endpoint,
      UwUBlog.Post
      # Start a worker by calling: UwUBlog.Worker.start_link(arg)
      # {UwUBlog.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UwUBlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UwUBlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
