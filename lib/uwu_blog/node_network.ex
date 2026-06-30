defmodule UwUBlog.NodeNetwork do
  @moduledoc """
  Tracks this node's public network identity — the egress public IP and the
  autonomous system (ASN) it leaves the internet through.

  Every node looks itself up once at boot and then on a slow interval (the data
  rarely changes), so the cluster dashboard can show where each node actually
  egresses from. The lookup runs in a supervised task, so reads never block on
  the network, and `refresh/0` forces an immediate re-check — wired to the
  dashboard's per-node refresh button.

  State is local to each node; `UwUBlog.Cluster` folds each node's snapshot into
  the stats it already collects over RPC. Lookups go through free, keyless
  IP/ASN providers tried in order until one answers.
  """

  use GenServer

  require Logger

  @refresh_interval :timer.hours(1)
  @receive_timeout :timer.seconds(10)

  defstruct ip: nil, asn: nil, as_org: nil, status: :pending, fetched_at: nil, task: nil

  @type snapshot :: %{
          ip: String.t() | nil,
          asn: non_neg_integer() | nil,
          as_org: String.t() | nil,
          status: :pending | :ok | :unavailable | {:error, term()},
          fetched_at: DateTime.t() | nil
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "This node's last known egress snapshot. Safe to call when not running."
  @spec get() :: snapshot()
  def get do
    case GenServer.whereis(__MODULE__) do
      nil -> unavailable()
      pid -> GenServer.call(pid, :get)
    end
  end

  @doc "Forces an immediate re-lookup. Returns before the lookup completes."
  def refresh(server \\ __MODULE__), do: GenServer.cast(server, :refresh)

  @impl true
  def init(_opts) do
    schedule_refresh()
    {:ok, %__MODULE__{}, {:continue, :lookup}}
  end

  @impl true
  def handle_continue(:lookup, state), do: {:noreply, start_lookup(state)}

  @impl true
  def handle_call(:get, _from, state), do: {:reply, snapshot(state), state}

  @impl true
  def handle_cast(:refresh, state), do: {:noreply, start_lookup(state)}

  @impl true
  def handle_info(:refresh, state) do
    schedule_refresh()
    {:noreply, start_lookup(state)}
  end

  def handle_info({ref, result}, %{task: %{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    {:noreply, apply_result(state, result)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task: %{ref: ref}} = state) do
    Logger.warning("[node_network] egress lookup crashed: #{inspect(reason)}")
    {:noreply, %{state | status: {:error, reason}, task: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Only one lookup in flight at a time; a refresh while one is running is a no-op.
  defp start_lookup(%{task: %Task{}} = state), do: state

  defp start_lookup(state) do
    task = Task.Supervisor.async_nolink(UwUBlog.TaskSupervisor, &lookup/0)
    %{state | status: :pending, task: task}
  end

  defp apply_result(state, {:ok, info}) do
    %{
      state
      | ip: info.ip,
        asn: info.asn,
        as_org: info.as_org,
        status: :ok,
        fetched_at: DateTime.utc_now(),
        task: nil
    }
  end

  defp apply_result(state, {:error, reason}) do
    Logger.warning("[node_network] egress lookup failed: #{inspect(reason)}")
    %{state | status: {:error, reason}, task: nil}
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, refresh_interval())

  defp snapshot(state), do: Map.take(state, [:ip, :asn, :as_org, :status, :fetched_at])

  defp unavailable, do: %{ip: nil, asn: nil, as_org: nil, status: :unavailable, fetched_at: nil}

  @doc false
  # Queries each provider in turn and returns the first usable answer.
  def lookup do
    Enum.reduce_while(providers(), {:error, :no_provider_answered}, fn {url, parser}, acc ->
      with {:ok, body} <- request(url),
           {:ok, info} <- parser.(body) do
        {:halt, {:ok, info}}
      else
        _ -> {:cont, acc}
      end
    end)
  end

  defp request(url) do
    options = [retry: false, receive_timeout: @receive_timeout] ++ req_options()

    case Req.get(url, options) do
      {:ok, %{status: 200, body: %{} = body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, {:http, reason}}
    end
  end

  # --- provider parsers: decoded JSON body -> %{ip, asn, as_org} ---

  @doc false
  # ipinfo.io: %{"ip" => "1.2.3.4", "org" => "AS13335 Cloudflare, Inc."}
  def parse_ipinfo(%{"ip" => ip} = body) when is_binary(ip) do
    {asn, org} = split_asn_org(body["org"])
    {:ok, %{ip: ip, asn: asn, as_org: org}}
  end

  def parse_ipinfo(_), do: :error

  @doc false
  # ipapi.co: %{"ip" => "1.2.3.4", "asn" => "AS13335", "org" => "Cloudflare, Inc."}
  def parse_ipapi(%{"ip" => ip} = body) when is_binary(ip) do
    {:ok, %{ip: ip, asn: parse_asn(body["asn"]), as_org: presence(body["org"])}}
  end

  def parse_ipapi(_), do: :error

  @doc false
  # ipwho.is: %{"ip" => "1.2.3.4", "connection" => %{"asn" => 13335, "org" => "..."}}
  def parse_ipwho(%{"ip" => ip} = body) when is_binary(ip) do
    conn = body["connection"] || %{}
    {:ok, %{ip: ip, asn: parse_asn(conn["asn"]), as_org: presence(conn["org"] || conn["isp"])}}
  end

  def parse_ipwho(_), do: :error

  defp split_asn_org(org) when is_binary(org) do
    case String.split(org, " ", parts: 2) do
      [asn, name] -> {parse_asn(asn), presence(name)}
      [asn] -> {parse_asn(asn), nil}
    end
  end

  defp split_asn_org(_), do: {nil, nil}

  defp parse_asn(asn) when is_integer(asn) and asn >= 0, do: asn

  defp parse_asn(asn) when is_binary(asn) do
    case Regex.run(~r/\d+/, asn) do
      [digits] -> String.to_integer(digits)
      _ -> nil
    end
  end

  defp parse_asn(_), do: nil

  defp presence(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp presence(_), do: nil

  defp providers do
    config(:providers) ||
      [
        {"https://ipinfo.io/json", &parse_ipinfo/1},
        {"https://ipapi.co/json/", &parse_ipapi/1},
        {"https://ipwho.is/", &parse_ipwho/1}
      ]
  end

  defp refresh_interval, do: config(:refresh_interval) || @refresh_interval

  defp req_options, do: config(:req_options) || []

  defp config(key), do: Application.get_env(:uwu_blog, __MODULE__, [])[key]
end
