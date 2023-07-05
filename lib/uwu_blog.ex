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
      }
    ]
  end

  def kira do
    [
      %{
        name: "<sup>^</sup>Makito<sup>^</sup>",
        link: "https://maki.to"
      },
      %{
        name: "千千",
        link: "https://wwyqianqian.github.io/"
      },
      %{
        name: "千夏",
        link: "https://blog.uuz.moe/"
      },
      %{
        name: "雪羽",
        link: "https://yukiha.live/"
      }
    ]
  end
end
