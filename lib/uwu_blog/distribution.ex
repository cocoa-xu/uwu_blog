defmodule UwUBlog.Distribution do
  @moduledoc """
  Brings the node up in distributed mode at boot so it can join the cluster.

  The deployment runs `mix phx.server` (an un-named VM), so we start Erlang
  distribution ourselves rather than relying on `--name`/`--cookie` flags.

  Naming matters for discovery: `DNSCluster` connects to peers as
  `<basename>@<ip>` for every IP that `DNS_CLUSTER_QUERY` resolves to, so each
  node must be named `<basename>@<own-ip>`. We use the node's Tailscale IPv4
  (from `tailscale ip -4`) as that IP. The cookie is the shared cluster secret,
  read from `RELEASE_COOKIE` (default `cookie`).

  Distribution only starts when clustering is configured (`:dns_cluster_query`
  set, i.e. prod with `DNS_CLUSTER_QUERY`) or a `RELEASE_NODE` is given; dev and
  test stay local automatically.
  """

  require Logger

  @basename "uwu_blog"

  @doc "Starts distribution if clustering is configured and we aren't already named."
  def ensure_started do
    cond do
      Node.alive?() -> :ok
      not enabled?() -> :ok
      true -> start()
    end
  rescue
    error ->
      Logger.error("[cluster] distribution setup raised: #{Exception.message(error)}; staying local")
      :ok
  catch
    kind, reason ->
      Logger.error("[cluster] distribution setup failed: #{inspect({kind, reason})}; staying local")
      :ok
  end

  defp enabled? do
    Application.get_env(:uwu_blog, :dns_cluster_query) not in [nil, ""] or
      System.get_env("RELEASE_NODE") not in [nil, ""]
  end

  defp start do
    case node_name() do
      nil ->
        Logger.warning(
          "[cluster] clustering is configured but no node name could be derived " <>
            "(set RELEASE_NODE, or make sure `tailscale` is on PATH and connected); staying local"
        )

        :ok

      name ->
        case :net_kernel.start(name, %{name_domain: :longnames}) do
          {:ok, _pid} ->
            Node.set_cookie(cookie())
            Logger.info("[cluster] distribution started as #{name}")
            :ok

          {:error, reason} ->
            Logger.error("[cluster] could not start distribution: #{inspect(reason)}")
            :ok
        end
    end
  end

  defp node_name do
    case System.get_env("RELEASE_NODE") do
      node when is_binary(node) and node != "" -> String.to_atom(node)
      _ -> if ip = tailscale_ipv4(), do: :"#{@basename}@#{ip}"
    end
  end

  defp cookie, do: String.to_atom(System.get_env("RELEASE_COOKIE") || "cookie")

  # Asks Tailscale for this node's IPv4. Returns nil when the CLI is missing or
  # Tailscale isn't connected; the node then stays local (or set RELEASE_NODE).
  defp tailscale_ipv4 do
    case System.cmd("tailscale", ["ip", "-4"], stderr_to_stdout: true) do
      {output, 0} -> parse_ip_output(output)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @doc false
  # Takes the first non-empty line of `tailscale ip -4` output.
  def parse_ip_output(output) do
    case String.split(output, "\n", trim: true) do
      [ip | _] -> String.trim(ip)
      [] -> nil
    end
  end
end
