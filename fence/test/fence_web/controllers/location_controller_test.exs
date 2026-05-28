defmodule FenceWeb.LocationControllerTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "POST /api/v1/location" do
    test "reports location", %{conn: conn} do
      conn =
        post(conn, "/api/v1/location", %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      assert %{"ok" => true, "location_id" => _} = json_response(conn, 200)
    end

    test "returns 401 without auth" do
      conn =
        build_conn() |> post("/api/v1/location", %{"latitude" => 37.0, "longitude" => -122.0})

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/groups/:id/locations" do
    test "returns group member locations", %{conn: conn, user: user} do
      group = create_group(user)

      Fence.Locations.report_location(user.id, %{
        "latitude" => 37.7749,
        "longitude" => -122.4194
      })

      conn = get(conn, "/api/v1/groups/#{group.id}/locations")
      assert %{"locations" => locs} = json_response(conn, 200)
      assert length(locs) == 1
      assert hd(locs)["user_id"] == user.id
      assert hd(locs)["latitude"]
    end

    test "includes geofence_presence in response", %{conn: conn, user: user} do
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "Office",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 500.0
        })

      Fence.Locations.update_geofence_state(
        user.id,
        MapSet.new([geofence.id]),
        MapSet.new()
      )

      conn = get(conn, "/api/v1/groups/#{group.id}/locations")
      response = json_response(conn, 200)
      assert Map.has_key?(response, "geofence_presence")
      assert length(response["geofence_presence"]) == 1

      entry = hd(response["geofence_presence"])
      assert entry["user_id"] == user.id
      assert entry["geofence_id"] == geofence.id
      assert entry["geofence_name"] == "Office"
      assert entry["geofence_latitude"]
      assert entry["geofence_longitude"]
      assert entry["sharing_mode"] == "live"
      assert entry["entered_at"]
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}/locations")
      assert json_response(conn, 403)
    end
  end
end
