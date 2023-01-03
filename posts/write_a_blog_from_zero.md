---
title: Write A Blog from Zero
date: 2023-01-02
excerpt: Writing a blog from scratch is fun!
permalink: blog-from-scratch
---

So I started to write my own blog using [Phoenix](https://www.phoenixframework.org/), and I'd like to use markdown files to store my posts. To parse the markdown files we can use [Earmark](https://hex.pm/packages/earmark), however, [Earmark](https://hex.pm/packages/earmark) does not support markdown file with frontmatter yet.

Frontmatter is a ting block of YAML code that sits in the front of a markdown file and stores some metadata in it, for exmaple, we can do `title`, `date` and `excerpt`. An instance of a frontmatter block would be something lile below,

```markdown
---
title: Write A Blog from Zero
date: 2023-01-02
excerpt: Writing a blog from scratch is fun!
---
```

We can use `:yaml_elixir` to parse YAML code in Elixir, and we'll use `YamlElixir.read_from_string/1` for this job,

```elixir
yaml_string = """
title: Write A Blog from Zero
date: 2023-01-02
excerpt: Writing a blog from scratch is fun!
"""
YamlElixir.read_from_string(yaml_string)
```

We will get the following output,

```elixir
{:ok,
 %{
   "date" => "2023-01-02",
   "excerpt" => "Writing a blog from scratch is fun!",
   "title" => "Write A Blog from Zero"
 }}
```

Another thing we might be interested in is `permalink`, for example, this post's permalink is set to `blog-from-scratch`, so the permanent link to this post is [`https://uwucocoa.moe/post/blog-from-scratch`](https://uwucocoa.moe/post/blog-from-scratch).

Well, sometimes I'm too lazy to come up with a good permalink, so I also wrote a function that automatically generates a permalink from the filename.

Then we can use the `frontmatter` we just generated in Phoenix template files.

```html
<article class="column post-section-title">
  <h2><a href={"/post/#{@post.frontmatter["permalink"]}"}><%= @post.frontmatter["title"] %></a></h2>
  <h3><%= @post.frontmatter["date"] %></h3>
  <div class="post">
    <%= raw @post.content %>
  </div>
</article>
```

Is there anything else I'd like to mention? Probably not...? There are definitely a lot of things I could do to further improve this blog, but it looks good at the moment. And since it's meant for my own use, and I don't really write that many posts, so the performance is not a concern for me, at least it's not a problem yet.

Anyway, happy 2023?
