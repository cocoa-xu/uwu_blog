defmodule UwUBlog.LogRedactorTest do
  use ExUnit.Case, async: true

  alias UwUBlog.LogRedactor

  @secret "GOCSPX-topsecret"
  @secrets [@secret]

  defp filter(msg), do: LogRedactor.filter(%{msg: msg, meta: %{}}, @secrets)

  test "redacts a secret inside a string message" do
    assert %{msg: {:string, redacted}} =
             filter({:string, ["client_secret=", @secret, " ok"]})

    string = IO.chardata_to_string(redacted)
    refute string =~ @secret
    assert string =~ "[REDACTED]"
  end

  test "leaves clean messages untouched" do
    msg = {:string, "nothing to see here"}
    assert filter(msg) == %{msg: msg, meta: %{}}
  end

  test "redacts secrets passed as format args" do
    assert %{msg: {"~ts", args}} = filter({"~ts", [@secret]})
    refute IO.chardata_to_string(args) =~ @secret
  end

  test "redacts secrets in report values but keeps other fields" do
    assert %{msg: {:report, report}} =
             filter({:report, %{token: @secret, user: "cocoa"}})

    refute inspect(report) =~ @secret
    assert report[:user] == "cocoa"
  end

  test "is a no-op when there are no secrets configured" do
    event = %{msg: {:string, @secret}, meta: %{}}
    assert LogRedactor.filter(event, []) == event
  end
end
