defmodule UwUBlogWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use UwUBlogWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import UwUBlogWeb.ConnCase

      # The default endpoint for testing
      @endpoint UwUBlogWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(UwUBlog.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, conn: build_sandboxed_conn(pid, tags[:async])}
  end

  # For async tests (ownership mode) the request process and any connected
  # LiveView (via UwUBlogWeb.LiveAcceptance) must be allowed onto the owner's
  # connection — we carry the metadata in the user-agent. Non-async tests run in
  # shared mode, where every process already sees the connection, so no metadata.
  defp build_sandboxed_conn(_pid, false), do: Phoenix.ConnTest.build_conn()

  defp build_sandboxed_conn(pid, true) do
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(UwUBlog.Repo, pid)

    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("user-agent", Phoenix.Ecto.SQL.Sandbox.encode_metadata(metadata))
  end

  @doc "Returns a conn carrying an authenticated admin session."
  def log_in_admin(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:admin_authenticated, true)
  end
end
