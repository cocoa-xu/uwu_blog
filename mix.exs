defmodule UwUBlog.MixProject do
  use Mix.Project

  def project do
    [
      app: :uwu_blog,
      version: "0.2.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      releases: [
        uwu_blog: [
          applications: [
            opentelemetry_exporter: :permanent,
            opentelemetry: :temporary
          ]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {UwUBlog.Application, []},
      extra_applications: [:logger, :runtime_tools, :phoenix_view]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bandit, "~> 1.2"},
      {:decorator, "~> 1.4"},
      {:dns, "~> 2.4.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:earmark, "~> 1.4"},
      {:ecto_sql, "~> 3.6"},
      {:gettext, "~> 0.24.0"},
      {:hackney, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:live_toast, "~> 0.6.4"},
      {:phoenix, "~> 1.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 0.20"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_view, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:swoosh, "~> 1.3"},
      {:yaml_elixir, "~> 2.9"},

      # dev/test
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:styler, "~> 1.0.0", only: :dev, runtime: false},
      {:floki, ">= 0.30.0", only: :test},

      # Telemetry and metrics
      {:sentry, "~> 10.2.0"},
      {:opentelemetry, "~> 1.0"},
      {:opentelemetry_api, "~> 1.0"},
      {:opentelemetry_cowboy, "~> 0.3"},
      {:opentelemetry_ecto, "~> 1.0"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_phoenix, "~> 1.0"},
      {:opentelemetry_req, "~> 0.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind uwu_blog", "esbuild uwu_blog"],
      "assets.deploy": [
        "tailwind uwu_blog --minify",
        "esbuild uwu_blog --minify",
        "phx.digest"
      ]
    ]
  end
end
