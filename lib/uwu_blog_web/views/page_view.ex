defmodule UwUBlogWeb.PageView do
  use UwUBlogWeb, :view

  def render("embed.html", %{post: post}=assigns) do
    body = UwUBlog.HTMLEngine.compile(post.frontmatter["template"]["heex"], [])
    {rendered, _} = Code.eval_quoted(body, [assigns: assigns])
    IO.inspect(rendered)
    rendered
  end
end
