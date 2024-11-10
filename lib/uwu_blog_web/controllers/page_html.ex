defmodule UwUBlogWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """

  use UwUBlog.Tracing.Decorator
  use UwUBlogWeb, :html

  embed_templates "page_html/*"

  @decorate trace()
  def embedded(%{template: template} = assigns) do
    template["heex"]
    |> UwUBlog.HTMLEngine.compile([])
    |> Code.eval_quoted(assigns: assigns)
    |> elem(0)
  end
end
