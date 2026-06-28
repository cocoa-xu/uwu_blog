defmodule UwUBlogWeb.AdminLive.Cluster do
  @moduledoc """
  Admin dashboard showing the live state of the Erlang/Elixir cluster: which
  nodes are connected over the tailnet and each node's BEAM runtime stats.

  Refreshes on a timer and reacts immediately to nodes joining/leaving via
  `:net_kernel.monitor_nodes/1`.
  """
  use UwUBlogWeb, :admin_live_view

  alias UwUBlog.Cluster

  @refresh_interval :timer.seconds(5)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :net_kernel.monitor_nodes(true)
      Process.send_after(self(), :refresh, @refresh_interval)
    end

    {:ok, socket |> assign(:page, :cluster) |> load()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_interval)
    {:noreply, load(socket)}
  end

  def handle_info({:nodeup, _node}, socket), do: {:noreply, load(socket)}
  def handle_info({:nodedown, _node}, socket), do: {:noreply, load(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp load(socket) do
    overview = Cluster.overview()
    node_stats = Enum.map(overview.nodes, fn node -> {node, Cluster.node_stats(node)} end)

    local =
      case List.keyfind(node_stats, overview.this_node, 0) do
        {_node, {:ok, stats}} -> stats
        _ -> nil
      end

    socket
    |> assign(:overview, overview)
    |> assign(:node_stats, node_stats)
    |> assign(:local, local)
  end

  # --- View helpers ---

  def node_label(node), do: to_string(node)

  def cluster_summary(%{distributed?: false}),
    do: "running on a single node — distribution isn't enabled yet"

  def cluster_summary(%{peers: []}), do: "this node only — no peers connected yet"

  def cluster_summary(%{peers: peers}) do
    "this node + #{length(peers)} #{pluralize(length(peers), "peer", "peers")} connected"
  end

  def pluralize(1, singular, _plural), do: singular
  def pluralize(_n, _singular, plural), do: plural

  def percent(_value, limit) when limit in [0, nil], do: 0

  def percent(value, limit) do
    (value / limit * 100) |> Float.round(1) |> min(100.0)
  end

  def format_bytes(n) when is_integer(n) do
    cond do
      n >= 1_073_741_824 -> "#{Float.round(n / 1_073_741_824, 1)} GB"
      n >= 1_048_576 -> "#{Float.round(n / 1_048_576, 1)} MB"
      n >= 1_024 -> "#{Float.round(n / 1_024, 1)} KB"
      true -> "#{n} B"
    end
  end

  def format_bytes(_), do: "—"

  def format_uptime(ms) when is_integer(ms) do
    seconds = div(ms, 1_000)
    days = div(seconds, 86_400)
    hours = rem(div(seconds, 3_600), 24)
    minutes = rem(div(seconds, 60), 60)
    secs = rem(seconds, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m"
      minutes > 0 -> "#{minutes}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  def format_uptime(_), do: "—"

  def format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  def format_number(_), do: "—"
end
