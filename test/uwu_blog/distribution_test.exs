defmodule UwUBlog.DistributionTest do
  use ExUnit.Case, async: true

  test "stays local when clustering is not configured" do
    # No :dns_cluster_query and no RELEASE_NODE in test, so this must be a no-op
    # and must not bring the node up distributed.
    assert UwUBlog.Distribution.ensure_started() == :ok
    refute Node.alive?()
  end
end
