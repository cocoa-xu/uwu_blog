defmodule UwUBlog.Cluster do
  @moduledoc """
  Read-only view of the Erlang/Elixir cluster and each node's BEAM runtime.

  The blog is moving onto several nodes connected over a tailnet (peer discovery
  is handled by `DNSCluster`); this is what the admin dashboard reads to show who
  is connected and how every node's VM is doing. Each function returns a plain
  snapshot — callers re-read to refresh.
  """

  alias UwUBlog.NodeNetwork

  @rpc_timeout 1_500

  @doc "Cluster membership and discovery config, from this node's perspective."
  def overview do
    this = Node.self()
    peers = Node.list()

    %{
      this_node: this,
      peers: peers,
      nodes: [this | peers],
      node_count: length(peers) + 1,
      distributed?: this != :nonode@nohost,
      cookie_set?: Node.get_cookie() != :nocookie,
      dns_query: Application.get_env(:uwu_blog, :dns_cluster_query)
    }
  end

  @doc """
  BEAM stats for `node`. Collected locally for `Node.self()`, otherwise over RPC
  with a short timeout so one unreachable peer can't stall the dashboard.
  """
  def node_stats(node) do
    if node == Node.self() do
      {:ok, collect_stats()}
    else
      case :rpc.call(node, __MODULE__, :collect_stats, [], @rpc_timeout) do
        {:badrpc, reason} -> {:error, reason}
        stats when is_map(stats) -> {:ok, stats}
      end
    end
  end

  @doc "Snapshot of the local node's runtime. Also invoked on peers via RPC."
  def collect_stats do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    memory = Map.new(:erlang.memory())

    %{
      otp_release: List.to_string(:erlang.system_info(:otp_release)),
      elixir_version: System.version(),
      architecture: List.to_string(:erlang.system_info(:system_architecture)),
      uptime_ms: uptime_ms,
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      port_count: :erlang.system_info(:port_count),
      port_limit: :erlang.system_info(:port_limit),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      schedulers_online: :erlang.system_info(:schedulers_online),
      schedulers: :erlang.system_info(:schedulers),
      run_queue: :erlang.statistics(:total_run_queue_lengths),
      memory_total: memory.total,
      memory_processes: Map.get(memory, :processes, 0),
      memory_binary: Map.get(memory, :binary, 0),
      memory_ets: Map.get(memory, :ets, 0),
      egress: NodeNetwork.get()
    }
  end

  @doc """
  Triggers an egress re-lookup on `node` (locally or over RPC). Fire-and-forget:
  the node refreshes asynchronously and the next `node_stats/1` reflects it.
  """
  def refresh_egress(node) do
    if node == Node.self() do
      NodeNetwork.refresh()
    else
      :rpc.call(node, NodeNetwork, :refresh, [], @rpc_timeout)
    end
  end
end
