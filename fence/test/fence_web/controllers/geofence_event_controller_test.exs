defmodule FenceWeb.GeofenceEventControllerTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "POST /api/v1/geofence-events" do
    test "reports an enter event for a valid geofence", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      params = %{
        "geofence_id" => geofence.id,
        "action" => "entered",
        "latitude" => 37.7749,
        "longitude" => -122.4194,
        "accuracy" => 10.0,
        "altitude" => 50.0,
        "speed" => 1.5,
        "bearing" => 90.0,
        "battery_level" => 0.85
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert %{"ok" => true, "verified" => _} = json_response(conn, 200)
    end

    test "reports an exit event for a valid geofence", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      params = %{
        "geofence_id" => geofence.id,
        "action" => "exited",
        "latitude" => 38.0,
        "longitude" => -123.0,
        "accuracy" => 10.0
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert %{"ok" => true, "verified" => _} = json_response(conn, 200)
    end

    test "returns 404 for non-existent geofence", %{conn: conn} do
      params = %{
        "geofence_id" => Ecto.UUID.generate(),
        "action" => "entered",
        "latitude" => 37.7749,
        "longitude" => -122.4194,
        "accuracy" => 10.0
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert json_response(conn, 404)
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      geofence = create_geofence(group, other)

      params = %{
        "geofence_id" => geofence.id,
        "action" => "entered",
        "latitude" => 37.7749,
        "longitude" => -122.4194,
        "accuracy" => 10.0
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert json_response(conn, 403)
    end

    test "returns 409 when user has opted out", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)
      {:ok, _} = Fence.Geofences.create_opt_out(user.id, geofence.id)

      params = %{
        "geofence_id" => geofence.id,
        "action" => "entered",
        "latitude" => 37.7749,
        "longitude" => -122.4194,
        "accuracy" => 10.0
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert json_response(conn, 409)
    end

    test "returns 422 for invalid action", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      params = %{
        "geofence_id" => geofence.id,
        "action" => "bogus",
        "latitude" => 37.7749,
        "longitude" => -122.4194,
        "accuracy" => 10.0
      }

      conn = post(conn, "/api/v1/geofence-events", params)
      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "returns 401 without auth" do
      conn =
        build_conn()
        |> post("/api/v1/geofence-events", %{
          "geofence_id" => Ecto.UUID.generate(),
          "action" => "entered",
          "latitude" => 37.0,
          "longitude" => -122.0
        })

      assert json_response(conn, 401)
    end
  end
end
