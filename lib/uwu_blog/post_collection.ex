defmodule UwUBlog.PostCollection do
  @moduledoc false

  use GenServer
  use UwUBlog.Tracing.Decorator

  alias UwUBlog.PostPending
  alias UwUBlog.Post

  require Logger

  defstruct [
    :posts,
    :posts_dir,
    :auto_reload_timer
  ]

  @type t :: %__MODULE__{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @decorate trace()
  def get_all_posts(pid \\ __MODULE__) do
    GenServer.call(pid, :get_all_posts)
  end

  @decorate trace()
  def get_post(pid \\ __MODULE__, permlink) do
    GenServer.call(pid, {:get_post, permlink})
  end

  @decorate trace()
  @spec permalink_to_dir(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def permalink_to_dir(permalink) do
    case get_post(permalink) do
      {:ok, post} ->
        {:ok, post.dir}

      _ ->
        {:error, :not_found}
    end
  end

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)

    state = %__MODULE__{
      posts: [],
      posts_dir: Application.get_env(:uwu_blog, __MODULE__)[:posts_dir] || "posts",
      auto_reload_timer: nil
    }

    {:ok, state, {:continue, :load_posts}}
  end

  @impl GenServer
  def handle_continue(:load_posts, state) do
    state = schedule_auto_reload(state)

    posts = load_posts(state.posts_dir)
    {:noreply, %{state | posts: posts}}
  end

  @impl GenServer
  def handle_info(:reload, state) do
    posts = load_posts(state.posts_dir)
    {:noreply, %{state | posts: posts}}
  end

  @impl GenServer
  def handle_call(:get_all_posts, _from, state) do
    {:reply, state.posts, state}
  end

  def handle_call({:get_post, permalink}, _from, state) do
    {result, state} = find_post(permalink, state)
    {:reply, result, state}
  end

  defp schedule_auto_reload(state) do
    if state.auto_reload_timer do
      Process.cancel_timer(state.auto_reload_timer)
    end

    timer = Process.send_after(self(), :reload, :timer.minutes(5))
    %{state | auto_reload_timer: timer}
  end

  @decorate trace()
  defp load_posts(posts_dir) do
    Logger.info("Loading posts")
    parse_posts(posts_dir)
  end

  @decorate trace()
  defp find_single_files(posts_dir) do
    Enum.map(Path.wildcard(Path.join(posts_dir, "*.md")), fn entry ->
      %PostPending{dir: posts_dir, entry: entry}
    end)
  end

  @decorate trace()
  defp find_post_in_subdirs(posts_dir) do
    case File.ls(posts_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&File.dir?("#{posts_dir}/#{&1}"))
        |> Enum.map(&Path.join([posts_dir, &1]))
        |> Enum.map(fn sub_dir ->
          Enum.map(Path.wildcard(Path.join(sub_dir, "*.md")), fn entry ->
            %PostPending{dir: sub_dir, entry: entry}
          end)
        end)
        |> List.flatten()

      _ ->
        []
    end
  end

  @decorate trace()
  defp parse_posts(posts_dir) do
    single_files = find_single_files(posts_dir)
    dir_entries = find_post_in_subdirs(posts_dir)

    (single_files ++ dir_entries)
    |> Enum.sort_by(
      fn %{entry: entry} ->
        File.stat!(entry).mtime
      end,
      :desc
    )
    |> Enum.map(&Post.process(&1))
  end

  @decorate trace()
  @spec find_post(permalink :: String.t(), state :: t()) ::
          {{:ok, list(Post.t())}, t()} | {{:error, :not_found}, t()}
  defp find_post(permalink, %{posts: posts} = state) do
    if post_index = Enum.find_index(posts, &(&1.permalink == permalink)) do
      post = Enum.at(posts, post_index)

      if File.exists?(post.entry) do
        if post.mtime != File.stat!(post.entry).mtime do
          updated_post = Post.process(post)
          new_posts = List.replace_at(posts, post_index, updated_post)
          {{:ok, updated_post}, %{state | posts: new_posts}}
        else
          {{:ok, post}, state}
        end
      else
        {{:error, :not_found}, %{state | posts: List.delete_at(posts, post_index)}}
      end
    else
      {{:error, :not_found}, state}
    end
  end
end
