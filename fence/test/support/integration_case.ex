defmodule Fence.IntegrationCase do
  @moduledoc """
  Test case for integration tests combining HTTP + WebSocket + Oban + PostGIS.

  All tests using this case are tagged with `:integration` and excluded
  from the default `mix test` run. Use `mix test --include integration`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint FenceWeb.Endpoint
      use FenceWeb, :verified_routes

      import Plug.Conn, except: [push: 3]
      import Phoenix.ConnTest, except: [connect: 2]
      import Phoenix.ChannelTest
      import Fence.Factory
      import Fence.IntegrationCase

      @moduletag :integration

      defp connect_user_socket(token) do
        {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})
        socket
      end

      defp join_group_channel(socket, group_id) do
        {:ok, _reply, socket} = subscribe_and_join(socket, "group:#{group_id}", %{})
        socket
      end
    end
  end

  setup tags do
    Fence.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Register a user via the HTTP API. Returns {user_data, access_token, refresh_token}."
  def register_via_api(conn, overrides \\ %{}) do
    params =
      %{
        "email" => Fence.Factory.unique_email(),
        "password" => "password123",
        "display_name" => "Test User"
      }
      |> Map.merge(overrides)

    resp =
      conn
      |> Phoenix.ConnTest.dispatch(FenceWeb.Endpoint, :post, "/api/v1/auth/register", params)
      |> Phoenix.ConnTest.json_response(201)

    {resp["user"], resp["access_token"], resp["refresh_token"]}
  end

  @doc "Add Bearer token header to a conn."
  def authed_conn_from_token(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc "Drain Oban queues in cascade order: geofence_checks first, then notifications."
  def drain_oban do
    Oban.drain_queue(Oban, queue: :geofence_checks)
    Oban.drain_queue(Oban, queue: :notifications)
  end

  @doc "Grant visibility between two users in a group (activates the pending pair)."
  def grant_mutual_visibility(user_id_a, user_id_b, group_id) do
    {:ok, _} = Fence.Groups.grant_visibility(user_id_a, group_id, user_id_b)
  end
end
