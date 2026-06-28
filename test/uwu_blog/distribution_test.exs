defmodule UwUBlog.DistributionTest do
  use ExUnit.Case, async: true

  test "stays local when clustering is not configured" do
    # No :dns_cluster_query and no RELEASE_NODE in test, so this must be a no-op
    # and must not bring the node up distributed.
    assert UwUBlog.Distribution.ensure_started() == :ok
    refute Node.alive?()
  end

  test "epmd_path/0 resolves to the ERTS epmd binary" do
    path = UwUBlog.Distribution.epmd_path()
    assert path =~ "epmd"
    assert File.exists?(path)
  end

  describe "parse_ip_output/1" do
    test "takes the first non-empty line of `tailscale ip -4`" do
      assert UwUBlog.Distribution.parse_ip_output("100.76.154.10\n") == "100.76.154.10"
      assert UwUBlog.Distribution.parse_ip_output("100.1.2.3\n") == "100.1.2.3"
    end

    test "returns nil for empty output" do
      assert UwUBlog.Distribution.parse_ip_output("") == nil
      assert UwUBlog.Distribution.parse_ip_output("\n") == nil
    end
  end
end
