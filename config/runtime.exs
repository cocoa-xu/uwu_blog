import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/uwu_blog start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :uwu_blog, UwUBlogWeb.Endpoint, server: true
end

honeycomb_api_key = System.get_env("HONEYCOMB_API_KEY")

if honeycomb_api_key do
  config :opentelemetry,
    resource: [
      service: [
        name: "uwu_blog"
      ]
    ]

  config :opentelemetry,
    traces_exporter: :otlp

  config :opentelemetry_exporter,
    otlp_protocol: :http_protobuf,
    otlp_endpoint: "https://api.honeycomb.io:443",
    otlp_headers: [
      {"x-honeycomb-team", honeycomb_api_key},
      {"x-honeycomb-dataset", "uwu_blog"}
    ]
end

storage_base_url = System.get_env("UWUBLOG_STORAGE_ENDPOINT")

if storage_base_url do
  config :uwu_blog, UwUBlog.Storage,
    provider:
      {UwUBlog.Stroage.C1,
       base_url: storage_base_url,
       public_url: "https://assets.uwucocoa.moe",
       bucket:
         System.get_env("UWUBLOG_STORAGE_BUCKET") || raise("UWUBLOG_STORAGE_BUCKET is missing"),
       aws_sigv4: [
         access_key_id:
           System.get_env("UWUBLOG_STORAGE_ACCESS_KEY_ID") ||
             raise("UWUBLOG_STORAGE_ACCESS_KEY_ID is missing"),
         secret_access_key:
           System.get_env("UWUBLOG_STORAGE_SECRET_ACCESS_KEY") ||
             raise("UWUBLOG_STORAGE_SECRET_ACCESS_KEY is missing"),
         service: "s3",
         region: "auto"
       ]}
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :uwu_blog, UwUBlog.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    ssl: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 3,
      server_name_indication: String.to_charlist(URI.parse(database_url).host),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ],
    socket_options: maybe_ipv6

  config :uwu_blog, UwUBlog.NowPlaying,
    apikey:
      System.get_env("NOW_PLAYING_APIKEY") ||
        raise("""
        environment variable NOW_PLAYING_APIKEY is missing.
        """)

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "uwucocoa.moe"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :uwu_blog, UwUBlogWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  config :uwu_blog, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :sentry,
    dsn: System.get_env("SENTRY_DSN") || raise("SENTRY_DSN is missing"),
    environment_name: Mix.env(),
    enable_source_code_context: true,
    root_source_code_paths: [File.cwd!()]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :uwu_blog, UwUBlogWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :uwu_blog, UwUBlogWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :uwu_blog, UwUBlog.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
