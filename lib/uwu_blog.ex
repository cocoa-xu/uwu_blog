defmodule UwUBlog do
  @moduledoc false

  def site_title do
    "Cocoa's Blog"
  end

  def nav_items do
    [
      %{
        name: "Home",
        href: "/"
      },
      %{
        name: "About",
        href: "/about"
      },
      %{
        name: "Now Playing",
        href: "/now_playing"
      }
    ]
  end
end
