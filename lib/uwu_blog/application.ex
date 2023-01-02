defmodule UwuBlog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      UwuBlog.Repo,
      # Start the Telemetry supervisor
      UwuBlogWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: UwuBlog.PubSub},
      # Start the Endpoint (http/https)
      UwuBlogWeb.Endpoint
      # Start a worker by calling: UwuBlog.Worker.start_link(arg)
      # {UwuBlog.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UwuBlog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UwuBlogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
