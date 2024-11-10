import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.

# In test we don't send emails.
config :uwu_blog, UwUBlog.Mailer, adapter: Swoosh.Adapters.Test

config :uwu_blog, UwUBlog.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "uwu_blog_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :uwu_blog, UwUBlogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "xF2/vbb/5R/pAj1NZBuPzPXUm5hOg4a+3VVz5AhuNpobdi4q04bfHn7rcmX/mJDR",
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Disable swoosh api client as it is only required for production adapters.
  enable_expensive_runtime_checks: true

config :swoosh, :api_client, false
