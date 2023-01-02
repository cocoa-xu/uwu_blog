defmodule UwuBlog.Repo do
  use Ecto.Repo,
    otp_app: :uwu_blog,
    adapter: Ecto.Adapters.Postgres
end
