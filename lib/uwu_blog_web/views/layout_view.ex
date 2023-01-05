defmodule UwUBlogWeb.LayoutView do
  use UwUBlogWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def site_title do
    UwUBlog.site_title
  end

  def nav_items do
    UwUBlog.nav_items
  end
end
