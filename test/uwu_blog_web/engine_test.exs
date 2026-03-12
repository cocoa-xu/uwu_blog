defmodule UwUBlog.HTMLEngineTest do
  use ExUnit.Case, async: true

  describe "compile/2" do
    test "compiles a simple HEEx template string" do
      template = ~s(<div>Hello World</div>)
      quoted = UwUBlog.HTMLEngine.compile(template, [])

      {result, _bindings} = Code.eval_quoted(quoted, assigns: %{})
      rendered = Phoenix.HTML.Safe.to_iodata(result)
      html = IO.iodata_to_binary(rendered)

      assert html =~ "<div>"
      assert html =~ "Hello World"
      assert html =~ "</div>"
    end

    test "compiles a template with EEx expressions" do
      template = ~s(<p><%= @name %></p>)
      quoted = UwUBlog.HTMLEngine.compile(template, [])

      {result, _bindings} = Code.eval_quoted(quoted, assigns: %{name: "Alice"})
      rendered = Phoenix.HTML.Safe.to_iodata(result)
      html = IO.iodata_to_binary(rendered)

      assert html =~ "<p>"
      assert html =~ "Alice"
    end

    test "compiles a template with Phoenix.HTML.raw" do
      template = ~s(<div><%= Phoenix.HTML.raw "<b>bold</b>" %></div>)
      quoted = UwUBlog.HTMLEngine.compile(template, [])

      {result, _bindings} = Code.eval_quoted(quoted, assigns: %{})
      rendered = Phoenix.HTML.Safe.to_iodata(result)
      html = IO.iodata_to_binary(rendered)

      assert html =~ "<b>bold</b>"
    end

    test "compiles an embedded blog post template (as used in embed_phoenix_templates post)" do
      # This simulates the exact use case from the blog post:
      # a custom HEEx template embedded in markdown frontmatter
      heex_template = """
      <article class="column post-section-title">
        <h2><%= @post.frontmatter["title"] %></h2>
        <div class="post">
          <%= Phoenix.HTML.raw @post.content %>
        </div>
      </article>
      """

      post = %{
        frontmatter: %{
          "title" => "Test Embedded Post",
          "permalink" => "test-embedded",
          "template" => %{"heex" => heex_template, "using" => "embed.html"}
        },
        content: "<p>Some <strong>HTML</strong> content</p>"
      }

      quoted = UwUBlog.HTMLEngine.compile(heex_template, [])
      {result, _bindings} = Code.eval_quoted(quoted, assigns: %{post: post})
      rendered = Phoenix.HTML.Safe.to_iodata(result)
      html = IO.iodata_to_binary(rendered)

      assert html =~ "Test Embedded Post"
      assert html =~ "<strong>HTML</strong>"
      assert html =~ ~s(class="column post-section-title")
    end
  end

  describe "classify_type/1" do
    test "classifies slots" do
      assert {:slot, "header"} = UwUBlog.HTMLEngine.classify_type(":header")
    end

    test "rejects :inner_block" do
      assert {:error, _} = UwUBlog.HTMLEngine.classify_type(":inner_block")
    end

    test "classifies remote components" do
      assert {:remote_component, "MyComponent"} =
               UwUBlog.HTMLEngine.classify_type("MyComponent")
    end

    test "classifies local components" do
      assert {:local_component, "my_component"} =
               UwUBlog.HTMLEngine.classify_type(".my_component")
    end

    test "classifies HTML tags" do
      assert {:tag, "div"} = UwUBlog.HTMLEngine.classify_type("div")
      assert {:tag, "span"} = UwUBlog.HTMLEngine.classify_type("span")
    end
  end

  describe "void?/1" do
    test "returns true for void elements" do
      assert UwUBlog.HTMLEngine.void?("br")
      assert UwUBlog.HTMLEngine.void?("img")
      assert UwUBlog.HTMLEngine.void?("input")
      assert UwUBlog.HTMLEngine.void?("hr")
    end

    test "returns false for non-void elements" do
      refute UwUBlog.HTMLEngine.void?("div")
      refute UwUBlog.HTMLEngine.void?("span")
      refute UwUBlog.HTMLEngine.void?("p")
    end
  end
end
