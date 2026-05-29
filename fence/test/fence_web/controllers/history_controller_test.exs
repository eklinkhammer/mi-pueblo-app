defmodule FenceWeb.HistoryControllerTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.{Groups, Locations}

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /api/v1/users/:user_id/history" do
    test "returns 200 with events for own history", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      Locations.update_geofence_state(
        user.id,
        MapSet.new([geofence.id]),
        MapSet.new()
      )

      conn = get(conn, "/api/v1/users/#{user.id}/history")
      assert %{"events" => events} = json_response(conn, 200)
      assert length(events) == 1

      event = hd(events)
      assert event["event"] == "entered"
      assert event["geofence_id"] == geofence.id
      assert event["geofence_name"] == "Test Geofence"
      assert event["id"]
      assert event["inserted_at"]
    end

    test "returns 200 with events for another user with active visibility pair",
         %{conn: conn, user: user} do
      other = create_user(%{"display_name" => "Other"})
      group = create_group(user)
      {:ok, invite} = Groups.get_or_create_invite(group.id, user.id)
      {:ok, _} = Groups.join_by_invite_code(other.id, invite.code)
      {:ok, _} = Groups.grant_visibility(user.id, group.id, other.id)

      geofence = create_geofence(group, user)

      Locations.update_geofence_state(
        other.id,
        MapSet.new([geofence.id]),
        MapSet.new()
      )

      conn = get(conn, "/api/v1/users/#{other.id}/history")
      assert %{"events" => events} = json_response(conn, 200)
      assert length(events) == 1
      assert hd(events)["event"] == "entered"
    end

    test "returns 403 for another user without visibility pair", %{conn: conn} do
      other = create_user(%{"display_name" => "Stranger"})

      conn = get(conn, "/api/v1/users/#{other.id}/history")
      assert json_response(conn, 403)
    end

    test "returns 400 for invalid UUID", %{conn: conn} do
      conn = get(conn, "/api/v1/users/not-a-uuid/history")
      assert %{"error" => %{"code" => "invalid_id"}} = json_response(conn, 400)
    end
  end
end
