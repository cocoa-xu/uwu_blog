---
title: Embedding Phoenix Templates in Markdown Files
date: 2023-01-04
excerpt: I don't know if it's right or wrong, but it's definitely an interesting thing to experiment.
permalink: embedding-phoenix-templates-in-markdown
template:
  using: "embed.html"
  heex: |
    <article class="column post-section-title">
      <h2><a href={"/post/#{@post.frontmatter["permalink"]}"}><%= @post.frontmatter["title"] %></a></h2>
      <h3><%= @post.frontmatter["date"] %></h3>
      <div class="post">
        <details open>
          <summary>Show template used in this post</summary>
          <pre><code class="html language-html"><%= @post.frontmatter["template"]["heex"] %></code></pre>
        </details>
        <%= Phoenix.HTML.raw @post.content %>
      </div>
    </article>
---

After I wrote my first ever blog in Phoenix, I was thinking about what interesting things I can experiment with it. And here it is! 

As you can see, this page has a `<details>` element at the top, and that is the HEEx template for this post. So, yes, I wrote the HEEx template inside a markdown file, compile it on-the-fly, and output itself in the rendered page!

Let's see how I made this possible.

### Write the HEEx Template in Markdown Frontmatter
In the last post, I mentioned how I parsed the frontmatter in a markdown file, and since the frontmatter is really just some YAML strings fenced by `---`, we can write anything we want inside it, that would of course include an HEEx template. For example,

```markdown
---
title: My Next Post
date: 2023-01-04
excerpt: What should I write?
permalink: next-post
template:
  using: "embed.html"
  heex: |
    <article class="column post-section-title">
      <div class="post">
        <h2>An HEEx template embbeded in a markdown file!</h2>
        <%= Phoenix.HTML.raw @post.content %>
      </div>
    </article>
---
```

### Conditional Rendering
After that, we need to check if the current post has a custom HEEx template, if so, we forward the rendering process to another module, say `UwUBlogWeb.PageView`. Otherwise, we use the normal template defined in `post.html.heex`. Therefore, I changed the code in `post.html.heex` to

```html
<%= if Map.has_key?(@post.frontmatter, "template") do %>
  <%= render(UwUBlogWeb.PageView, @post.frontmatter["template"]["using"], post: @post) %>
<% else %>
  <article class="column post-section-title">
    <h2><a href={"/post/#{@post.frontmatter["permalink"]}"}><%= @post.frontmatter["title"] %></a></h2>
    <h3><%= @post.frontmatter["date"] %></h3>
    <div class="post">
      <%= raw @post.content %>
    </div>
  </article>
<% end %>
```

The reason we can do this is because we can call `Phoenix.View.render/3` and explicitly render the template. You can find a bit more information on Phoenix's hexdocs page, [Manually rendering templates](https://hexdocs.pm/phoenix/views.html#manually-rendering-templates). I'll mention the code in `UwUBlogWeb.PageView` later.

However, it wouldn't be that simple because the compilation of HEEx templates usually happens, well, at compile-time, via the `Phoenix.LiveView.HTMLEngine`. It expects either a `.heex` template file or a `~H` sigil, instead of the template we embedded in a markdown file.

### Customise the HTMLEngine
Hence, I did some kind of reverse engineering and found that I need to customise the `Phoenix.LiveView.HTMLEngine` and create my own `UwUBlog.HTMLEngine` to fulfill this purpose. The reason is that `Phoenix.LiveView.HTMLEngine.compile/2` calls to `EEx.compile_file/2`, and of course we can't pass a markdown file and expect it to do what we want (unless we customise it, but that's basically the same thing here). Luckily, we have `EEx.compile_string/2` available to us, and we can retrieve the HEEx template string from the frontmatter. 

So I copied the code from `Phoenix.LiveView.HTMLEngine` and modified the `compile/2` function,

```elixir
defmodule UwUBlog.HTMLEngine do
  # ...
  def compile(string, _name) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    EEx.compile_string(string, engine: __MODULE__, line: 1, trim: trim)
  end
  # ...
end
```

### Compile HEEx Template on-the-fly and Render the Page
Now I need to figure out a way to connect everything in the `UwUBlogWeb.PageView` module. For the `render/2` function in a Phoenix view, it expects two arguments: the template name and the assigns. Here I decided to use `"embed.html"` as the name.

Note that the variable `assigns` here is constructed in the true branch of the conditional rendering `if`-statement,

```html
<%= if Map.has_key?(@post.frontmatter, "template") do %>
  <%= render(UwUBlogWeb.PageView, @post.frontmatter["template"]["using"], post: @post) %>
<% else %>
```

Therefore the `assigns` variable will have a single key, `post`, and that's really all I need: the value of the `post` key contains the following information,

```elixir
%{
  content: "...",
  file: "posts/next_post.md",
  frontmatter: %{
    "date" => "2023-01-04",
    "excerpt" => "What should I write?",
    "permalink" => "next-post",
    "template" => %{
      "heex" => "<article class=\"column post-section-title\">\n  <div class=\"post\">\n    <h2>An HEEx template embbeded in a markdown file!</h2>\n    <%= Phoenix.HTML.raw @post.content %>\n  </div>\n</article>\n",
      "using" => "embed.html"
    },
    "title" => "My Next Post"
  },
  ...
}
```

Now I can compile the embeded HEEx template via `UwUBlog.HTMLEngine.compile/2`.

```elixir
def render("embed.html", %{post: post}=assigns) do
  body = UwUBlog.HTMLEngine.compile(post.frontmatter["template"]["heex"], [])
  # ...
end
```

The return value is the compiled Elixir AST, and it looks like this,

```elixir
{:__block__, [],
 [
   {:require, [context: UwUBlog.HTMLEngine],
    [{:__aliases__, [alias: false], [:Phoenix, :LiveView, :Helpers]}]},
    # ...
        {:%, [],
          [
            {:__aliases__, [alias: false], [:Phoenix, :LiveView, :Rendered]},
            {:%{}, [],
             [
               static: ["<article class=\"column post-section-title\">\n  <div class=\"post\">\n    <h2>An HEEx template embbeded in a markdown file!</h2>\n", "\n  </div>\n</article>"],
               dynamic: {:dynamic, [], Phoenix.LiveView.Engine},
               fingerprint: 84211337665366584396207549738045929506,
               root: true
             ]}
          ]}
       ]}
    ]}
 ]}
```

Since we have the AST, or we call it the quoted form in Elixir, the next step is to evaluate it with `Code.eval_quoted/2`. Also, don't forget to pass in the binding list because we are doing it at runtime, so the variable `assigns` in the AST is not bonded and that will cause an error.

The first element in the tuple returned by `Code.eval_quoted` will be the `%Phoenix.LiveView.Rendered{}` struct.

```elixir
%Phoenix.LiveView.Rendered{
  static: ["<article class=\"column post-section-title\">\n  <div class=\"post\">\n    <h2>An HEEx template embbeded in a markdown file!</h2>\n", "\n  </div>\n</article>"],
  dynamic: #Function<42.3316493/1 in :erl_eval.expr/6>,
  fingerprint: 84211337665366584396207549738045929506,
  root: true
}
```

Then we can simply use it as the return value of the `UwUBlogWeb.PageView.render/2` function, and we are done! I don't even need to attach a screenshot here because what you are viewing is the result. :D

```elixir
def render("embed.html", %{post: post}=assigns) do
  body = UwUBlog.HTMLEngine.compile(post.frontmatter["template"]["heex"], [])
  {rendered, _} = Code.eval_quoted(body, [assigns: assigns])
  rendered
end
```

### But why?
First of all, it's interesting! 

The second point to do this is that if I ever need to create a special page for that one post, I can write the one-off template in that very markdown file instead of putting a single-use template somewhere in the project.
