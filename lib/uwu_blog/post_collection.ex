defmodule UwUBlog.PostCollection do
  @moduledoc """
  In-memory cache of compiled blog posts.

  Compiled `UwUBlog.Post` structs live in a `read_concurrency` ETS table that
  request processes read directly — there is no GenServer round-trip on the hot
  path, so reads never serialize behind a recompile. This GenServer is the
  table's sole writer: at boot it eagerly compiles the most recent `:eager_limit`
  posts, indexes every post by permalink (a cheap frontmatter peek), and compiles
  the older tail lazily on first access.

  Invalidation is incremental. On Linux it subscribes to filesystem events
  (inotify, via `:file_system`) and recompiles only what actually changed; on
  other platforms it falls back to a periodic incremental reconcile. Either way a
  blind full re-parse never blocks reads.
  """

  use GenServer
  use UwUBlog.Tracing.Decorator

  alias UwUBlog.Post
  alias UwUBlog.PostPending

  require Logger

  @table :uwu_blog_posts
  @index_key :__index__
  @watching_key :__watching__
  @ready_key :__ready__
  @default_eager_limit 25
  @default_reload_interval :timer.minutes(5)
  @debounce_ms 250

  defstruct [
    :posts_dir,
    :eager_limit,
    :watching?,
    :reload_interval,
    :watcher_pid,
    :reconcile_timer
  ]

  @type index_entry :: %{
          permalink: String.t(),
          entry: String.t(),
          dir: String.t(),
          mtime: :calendar.datetime()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ── Reads: straight from ETS, no GenServer call ───────────────────────────

  @decorate trace()
  @spec get_all_posts() :: [Post.t()]
  def get_all_posts do
    await_ready()

    index()
    |> Enum.take(eager_limit())
    |> Enum.flat_map(fn entry ->
      case lookup_post(entry.permalink) do
        {:ok, post} -> [post]
        :error -> []
      end
    end)
  end

  @decorate trace()
  @spec get_post(String.t()) :: {:ok, Post.t()} | {:error, :not_found}
  def get_post(permalink) do
    await_ready()

    case lookup_post(permalink) do
      {:ok, post} ->
        if stale?(post),
          do: GenServer.call(__MODULE__, {:recompile, permalink}),
          else: {:ok, post}

      :error ->
        if known?(permalink),
          do: GenServer.call(__MODULE__, {:recompile, permalink}),
          else: {:error, :not_found}
    end
  end

  @decorate trace()
  @spec permalink_to_dir(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def permalink_to_dir(permalink) do
    await_ready()

    case Enum.find(index(), &(&1.permalink == permalink)) do
      %{dir: dir} -> {:ok, dir}
      nil -> {:error, :not_found}
    end
  end

  # ── Writer (GenServer) ────────────────────────────────────────────────────

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)

    config = Application.get_env(:uwu_blog, __MODULE__, [])

    :ets.new(@table, [:named_table, :protected, :set, read_concurrency: true])

    state = %__MODULE__{
      posts_dir: config[:posts_dir] || "posts",
      eager_limit: config[:eager_limit] || @default_eager_limit,
      watching?: watch?(config),
      reload_interval: config[:reload_interval] || @default_reload_interval,
      watcher_pid: nil,
      reconcile_timer: nil
    }

    {:ok, state, {:continue, :setup}}
  end

  @impl GenServer
  def handle_continue(:setup, state) do
    state = start_watching(state)
    :ets.insert(@table, {@watching_key, state.watching?})
    reconcile(state)
    :ets.insert(@table, {@ready_key, true})
    {:noreply, state}
  end

  # Reads that race a cold boot block here until the initial compile finishes: a
  # call queues behind `handle_continue`, so it returns only once the cache is
  # warm. Once ready, reads skip this entirely and hit ETS directly.
  @impl GenServer
  def handle_call(:await_ready, _from, state), do: {:reply, :ok, state}

  def handle_call({:recompile, permalink}, _from, state) do
    {:reply, compile_one(permalink), state}
  end

  # inotify event (Linux): debounce, then reconcile only what changed.
  @impl GenServer
  def handle_info({:file_event, pid, {_path, _events}}, %{watcher_pid: pid} = state) do
    {:noreply, debounce_reconcile(state)}
  end

  def handle_info({:file_event, pid, :stop}, %{watcher_pid: pid} = state) do
    Logger.warning("posts watcher stopped; falling back to periodic reload")
    {:noreply, fall_back_to_periodic(state)}
  end

  def handle_info({:EXIT, pid, reason}, %{watcher_pid: pid} = state) do
    Logger.warning("posts watcher exited (#{inspect(reason)}); falling back to periodic reload")
    {:noreply, fall_back_to_periodic(state)}
  end

  def handle_info(:reconcile, state) do
    reconcile(state)
    {:noreply, if(state.watching?, do: state, else: schedule_periodic(state))}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ── Reconcile (incremental) ───────────────────────────────────────────────

  @decorate trace()
  defp reconcile(state) do
    entries = scan(state.posts_dir)
    :ets.insert(@table, {@index_key, entries})

    eager = MapSet.new(Enum.take(entries, state.eager_limit), & &1.permalink)
    present = MapSet.new(entries, & &1.permalink)

    Enum.each(entries, fn entry ->
      cond do
        # Eager window: guaranteed compiled, refreshed when the file changed.
        MapSet.member?(eager, entry.permalink) -> ensure_compiled(entry)
        # Older tail: only refresh entries we've already compiled lazily.
        stale_cache?(entry) -> compile_and_store(entry)
        true -> :ok
      end
    end)

    prune(present)
    :ok
  end

  defp ensure_compiled(entry) do
    if cached_mtime(entry.permalink) == entry.mtime, do: :ok, else: compile_and_store(entry)
  end

  defp stale_cache?(entry) do
    case cached_mtime(entry.permalink) do
      nil -> false
      mtime -> mtime != entry.mtime
    end
  end

  defp compile_one(permalink) do
    case Enum.find(index(), &(&1.permalink == permalink)) do
      nil ->
        {:error, :not_found}

      entry ->
        if File.exists?(entry.entry) do
          case compile_and_store(entry) do
            %Post{} = post -> {:ok, post}
            _ -> {:error, :not_found}
          end
        else
          :ets.delete(@table, {:post, permalink})
          {:error, :not_found}
        end
    end
  end

  @decorate trace()
  defp compile_and_store(entry) do
    post = Post.process(%PostPending{entry: entry.entry, dir: entry.dir})
    :ets.insert(@table, {{:post, entry.permalink}, post})
    post
  rescue
    e ->
      Logger.error("failed to compile post #{entry.entry}: #{Exception.message(e)}")
      nil
  end

  defp prune(present) do
    collect = fn
      {{:post, permalink}, _post}, acc -> [permalink | acc]
      _other, acc -> acc
    end

    :ets.foldl(collect, [], @table)
    |> Enum.reject(&MapSet.member?(present, &1))
    |> Enum.each(&:ets.delete(@table, {:post, &1}))
  end

  @spec scan(String.t()) :: [index_entry()]
  defp scan(posts_dir) do
    (single_files(posts_dir) ++ subdir_files(posts_dir))
    |> Enum.map(fn %PostPending{entry: entry, dir: dir} ->
      %{
        permalink: Post.resolve_permalink(entry),
        entry: entry,
        dir: dir,
        mtime: File.stat!(entry).mtime
      }
    end)
    |> Enum.sort_by(& &1.mtime, :desc)
  end

  defp single_files(posts_dir) do
    posts_dir
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.map(&%PostPending{dir: posts_dir, entry: &1})
  end

  defp subdir_files(posts_dir) do
    case File.ls(posts_dir) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(posts_dir, &1))
        |> Enum.filter(&File.dir?/1)
        |> Enum.flat_map(fn sub_dir ->
          sub_dir
          |> Path.join("*.md")
          |> Path.wildcard()
          |> Enum.map(&%PostPending{dir: sub_dir, entry: &1})
        end)

      _ ->
        []
    end
  end

  # ── Watching / periodic fallback ──────────────────────────────────────────

  defp watch?(config) do
    case config[:watch] do
      nil -> match?({:unix, :linux}, :os.type())
      other -> !!other
    end
  end

  defp start_watching(%{watching?: false} = state), do: schedule_periodic(state)

  defp start_watching(%{watching?: true} = state) do
    case start_file_system(state.posts_dir) do
      {:ok, pid} ->
        FileSystem.subscribe(pid)
        Logger.info("Watching #{state.posts_dir} for changes (inotify)")
        %{state | watcher_pid: pid}

      other ->
        Logger.warning("Could not start posts watcher (#{inspect(other)}); periodic reload")
        schedule_periodic(%{state | watching?: false})
    end
  end

  defp start_file_system(posts_dir) do
    FileSystem.start_link(dirs: [Path.expand(posts_dir)])
  rescue
    e -> {:error, e}
  catch
    :exit, reason -> {:error, reason}
  end

  defp fall_back_to_periodic(state) do
    :ets.insert(@table, {@watching_key, false})
    schedule_periodic(%{state | watcher_pid: nil, watching?: false})
  end

  defp schedule_periodic(state) do
    state = cancel_timer(state)
    %{state | reconcile_timer: Process.send_after(self(), :reconcile, state.reload_interval)}
  end

  defp debounce_reconcile(state) do
    state = cancel_timer(state)
    %{state | reconcile_timer: Process.send_after(self(), :reconcile, @debounce_ms)}
  end

  defp cancel_timer(%{reconcile_timer: nil} = state), do: state

  defp cancel_timer(%{reconcile_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | reconcile_timer: nil}
  end

  # ── ETS helpers ───────────────────────────────────────────────────────────

  defp index do
    case safe_lookup(@index_key) do
      [{@index_key, entries}] -> entries
      _ -> []
    end
  end

  defp lookup_post(permalink) do
    case safe_lookup({:post, permalink}) do
      [{_key, post}] -> {:ok, post}
      _ -> :error
    end
  end

  defp cached_mtime(permalink) do
    case safe_lookup({:post, permalink}) do
      [{_key, %Post{mtime: mtime}}] -> mtime
      _ -> nil
    end
  end

  defp known?(permalink), do: Enum.any?(index(), &(&1.permalink == permalink))

  defp await_ready do
    unless ready?(), do: GenServer.call(__MODULE__, :await_ready, :infinity)
    :ok
  end

  defp ready? do
    case safe_lookup(@ready_key) do
      [{@ready_key, true}] -> true
      _ -> false
    end
  end

  # In watch mode the inotify reconcile keeps ETS authoritative, so reads skip the
  # filesystem entirely. Off it (dev/macOS), revalidate against the file's mtime so
  # edits show up immediately without a server restart.
  defp stale?(post), do: not watching?() and file_changed?(post)

  defp watching? do
    case safe_lookup(@watching_key) do
      [{@watching_key, value}] -> value
      _ -> false
    end
  end

  defp file_changed?(%Post{entry: entry, mtime: mtime}) do
    case File.stat(entry) do
      {:ok, %{mtime: ^mtime}} -> false
      _ -> true
    end
  end

  defp eager_limit do
    Application.get_env(:uwu_blog, __MODULE__, [])[:eager_limit] || @default_eager_limit
  end

  defp safe_lookup(key) do
    :ets.lookup(@table, key)
  rescue
    ArgumentError -> []
  end
end
