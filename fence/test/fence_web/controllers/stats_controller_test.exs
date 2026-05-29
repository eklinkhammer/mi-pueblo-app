defmodule FenceWeb.StatsControllerTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.{Geofences, Locations}

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /api/v1/stats" do
    test "returns 200 with empty stats when no home claimed", %{conn: conn} do
      conn = get(conn, "/api/v1/stats")
      assert %{"stats" => []} = json_response(conn, 200)
    end

    test "returns 200 with stats when home is claimed", %{conn: conn, user: user} do
      group = create_group(user)
      home = create_geofence(group, user, %{"name" => "Home"})

      {:ok, _} = Geofences.claim_home(user.id, home.id, group.id)

      Locations.update_geofence_state(user.id, MapSet.new([home.id]), MapSet.new())

      conn = get(conn, "/api/v1/stats")
      assert %{"stats" => [stat]} = json_response(conn, 200)

      assert stat["group_id"] == group.id
      assert stat["group_name"] == "Test Group"
      assert stat["home_geofence_name"] == "Home"
      assert stat["home_visit_count"] == 1
      assert stat["housemates"] == []
      assert stat["your_top_geofences"] == []
    end

    test "returns 401 when not authenticated", %{conn: _conn} do
      conn = build_conn() |> get("/api/v1/stats")
      assert json_response(conn, 401)
    end
  end
end
