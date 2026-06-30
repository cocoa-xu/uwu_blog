defmodule UwUBlog.NodeNetworkTest do
  use ExUnit.Case, async: true

  alias UwUBlog.NodeNetwork

  describe "provider parsers" do
    test "ipinfo splits the AS number and org out of the org string" do
      assert {:ok, %{ip: "1.2.3.4", asn: 13_335, as_org: "Cloudflare, Inc."}} =
               NodeNetwork.parse_ipinfo(%{"ip" => "1.2.3.4", "org" => "AS13335 Cloudflare, Inc."})
    end

    test "ipinfo tolerates a missing org" do
      assert {:ok, %{ip: "1.2.3.4", asn: nil, as_org: nil}} =
               NodeNetwork.parse_ipinfo(%{"ip" => "1.2.3.4"})
    end

    test "ipapi reads the AS number out of the asn field" do
      assert {:ok, %{ip: "203.0.113.7", asn: 64_500, as_org: "Example Net"}} =
               NodeNetwork.parse_ipapi(%{
                 "ip" => "203.0.113.7",
                 "asn" => "AS64500",
                 "org" => "Example Net"
               })
    end

    test "ipwho reads a numeric asn from the connection block" do
      assert {:ok, %{ip: "198.51.100.9", asn: 64_501, as_org: "Example ISP"}} =
               NodeNetwork.parse_ipwho(%{
                 "ip" => "198.51.100.9",
                 "connection" => %{"asn" => 64_501, "org" => "Example ISP"}
               })
    end

    test "a body without an ip is rejected" do
      assert :error = NodeNetwork.parse_ipinfo(%{"org" => "AS13335 Cloudflare"})
      assert :error = NodeNetwork.parse_ipapi(%{"error" => true})
      assert :error = NodeNetwork.parse_ipwho(%{"success" => false})
    end
  end

  describe "lookup/0" do
    test "returns the first provider that answers" do
      Req.Test.stub(NodeNetwork, fn conn ->
        case conn.host do
          "ipinfo.io" ->
            Req.Test.json(conn, %{"ip" => "203.0.113.1", "org" => "AS64496 First Net"})

          other ->
            flunk("unexpected provider hit: #{other}")
        end
      end)

      assert {:ok, %{ip: "203.0.113.1", asn: 64_496, as_org: "First Net"}} = NodeNetwork.lookup()
    end

    test "falls through to the next provider when one fails" do
      Req.Test.stub(NodeNetwork, fn conn ->
        case conn.host do
          "ipinfo.io" ->
            Plug.Conn.send_resp(conn, 500, "down")

          "ipapi.co" ->
            Req.Test.json(conn, %{
              "ip" => "203.0.113.7",
              "asn" => "AS64500",
              "org" => "Example Net"
            })
        end
      end)

      assert {:ok, %{ip: "203.0.113.7", asn: 64_500, as_org: "Example Net"}} =
               NodeNetwork.lookup()
    end

    test "errors when no provider answers" do
      Req.Test.stub(NodeNetwork, fn conn -> Plug.Conn.send_resp(conn, 503, "nope") end)
      assert {:error, _reason} = NodeNetwork.lookup()
    end
  end

  test "get/0 is safe when the server isn't running" do
    assert %{status: :unavailable, ip: nil, asn: nil} = NodeNetwork.get()
  end
end
