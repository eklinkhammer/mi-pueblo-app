defmodule FenceWeb.ConnCase do
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
  by setting `use FenceWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint FenceWeb.Endpoint

      use FenceWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import FenceWeb.ConnCase
    end
  end

  setup tags do
    Fence.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defmacro live_authed(conn, user, path) do
    quote do
      {:ok, st} = Fence.Accounts.create_share_token(unquote(user).id)
      sep = if String.contains?(unquote(path), "?"), do: "&", else: "?"
      live(unquote(conn), "#{unquote(path)}#{sep}token=#{st.token}")
    end
  end

  defmacro live_admin(conn, path) do
    quote do
      {admin_user, admin_pass} = Application.get_env(:fence, :admin_credentials)

      unquote(conn)
      |> put_req_header("authorization", "Basic " <> Base.encode64("#{admin_user}:#{admin_pass}"))
      |> live(unquote(path))
    end
  end
end
