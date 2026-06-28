defmodule UwUBlog.SecretTest do
  use ExUnit.Case, async: true

  alias UwUBlog.Secret

  test "wraps a non-empty string and reveals it" do
    assert "super-secret" == "super-secret" |> Secret.new() |> Secret.reveal()
  end

  test "treats blank/missing values as nil so callers fail closed" do
    assert Secret.new(nil) == nil
    assert Secret.new("") == nil
    assert Secret.reveal(nil) == nil
  end

  test "inspect never exposes the value" do
    secret = Secret.new("GOCSPX-do-not-leak")
    assert inspect(secret) == "#UwUBlog.Secret<[REDACTED]>"
    refute inspect(secret) =~ "do-not-leak"
  end

  test "the value does not leak when nested inside other structures" do
    wrapped = %{credentials: [Secret.new("GOCSPX-do-not-leak")]}
    refute inspect(wrapped) =~ "do-not-leak"
  end

  test "string interpolation raises instead of leaking" do
    secret = Secret.new("GOCSPX-do-not-leak")
    assert_raise Protocol.UndefinedError, fn -> "#{secret}" end
  end
end
