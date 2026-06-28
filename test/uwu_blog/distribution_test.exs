defmodule UwUBlog.DistributionTest do
  use ExUnit.Case, async: true

  test "stays local when clustering is not configured" do
    # No :dns_cluster_query and no RELEASE_NODE in test, so this must be a no-op
    # and must not bring the node up distributed.
    assert UwUBlog.Distribution.ensure_started() == :ok
    refute Node.alive?()
  end

  describe "find_tailscale_ipv4/1" do
    test "picks the 100.64.0.0/10 address and ignores the rest" do
      ifaddrs = [
        {~c"lo0", [flags: [:up, :loopback], addr: {127, 0, 0, 1}, addr: {0, 0, 0, 0, 0, 0, 0, 1}]},
        {~c"en0", [flags: [:up], addr: {192, 168, 1, 5}]},
        {~c"utun3", [flags: [:up], addr: {100, 96, 0, 7}, addr: {0xFD7A, 0, 0, 0, 0, 0, 0, 1}]}
      ]

      assert UwUBlog.Distribution.find_tailscale_ipv4(ifaddrs) == "100.96.0.7"
    end

    test "returns nil with no tailnet address (real loopback shape)" do
      ifaddrs = [
        {~c"lo0",
         [
           flags: [:up, :loopback, :running],
           addr: {127, 0, 0, 1},
           netmask: {255, 0, 0, 0},
           addr: {0, 0, 0, 0, 0, 0, 0, 1},
           hwaddr: [0, 0, 0, 0, 0, 0]
         ]}
      ]

      assert UwUBlog.Distribution.find_tailscale_ipv4(ifaddrs) == nil
    end
  end
end
