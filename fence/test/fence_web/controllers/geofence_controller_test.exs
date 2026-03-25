defmodule FenceWeb.GeofenceControllerTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /api/v1/groups/:id/geofences" do
    test "lists geofences for member", %{conn: conn, user: user} do
      group = create_group(user)
      _geofence = create_geofence(group, user)

      conn = get(conn, "/api/v1/groups/#{group.id}/geofences")
      assert %{"geofences" => geofences} = json_response(conn, 200)
      assert length(geofences) == 1
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}/geofences")
      assert json_response(conn, 403)
    end
  end

  describe "POST /api/v1/groups/:id/geofences" do
    test "creates geofence", %{conn: conn, user: user} do
      group = create_group(user)

      params = %{
        "name" => "My Fence",
        "radius_meters" => 500.0,
        "latitude" => 37.7749,
        "longitude" => -122.4194
      }

      conn = post(conn, "/api/v1/groups/#{group.id}/geofences", params)
      assert %{"geofence" => g} = json_response(conn, 201)
      assert g["name"] == "My Fence"
      assert g["latitude"]
      assert g["longitude"]
      assert g["radius_meters"] == 500.0
    end

    test "sets default expiry when not provided", %{conn: conn, user: user} do
      group = create_group(user)

      params = %{
        "name" => "My Fence",
        "radius_meters" => 500.0,
        "latitude" => 37.7749,
        "longitude" => -122.4194
      }

      conn = post(conn, "/api/v1/groups/#{group.id}/geofences", params)
      assert %{"geofence" => g} = json_response(conn, 201)
      assert g["expires_at"]
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)

      conn =
        post(conn, "/api/v1/groups/#{group.id}/geofences", %{
          "name" => "F",
          "radius_meters" => 100.0,
          "latitude" => 37.0,
          "longitude" => -122.0
        })

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/groups/:gid/geofences/:fid" do
    test "shows geofence for member", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn = get(conn, "/api/v1/groups/#{group.id}/geofences/#{geofence.id}")
      assert %{"geofence" => g} = json_response(conn, 200)
      assert g["id"] == geofence.id
    end

    test "returns 404 for missing geofence", %{conn: conn, user: user} do
      group = create_group(user)
      conn = get(conn, "/api/v1/groups/#{group.id}/geofences/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/groups/:gid/geofences/:fid" do
    test "updates geofence", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/geofences/#{geofence.id}", %{"name" => "Updated"})

      assert %{"geofence" => g} = json_response(conn, 200)
      assert g["name"] == "Updated"
    end
  end

  describe "DELETE /api/v1/groups/:gid/geofences/:fid" do
    test "deletes geofence", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn = delete(conn, "/api/v1/groups/#{group.id}/geofences/#{geofence.id}")
      assert response(conn, 204)
    end
  end

  describe "subscriptions" do
    test "GET shows nil when no subscription", %{conn: conn, user: user} do
      admin = create_user()
      group = create_group(admin)

      # Add user as a member so they can query, but they didn't create the geofence
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(user.id, invite.code)

      geofence = create_geofence(group, admin)

      conn = get(conn, "/api/v1/geofences/#{geofence.id}/subscription")
      assert %{"subscription" => nil} = json_response(conn, 200)
    end

    test "PUT upserts subscription", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn =
        put(conn, "/api/v1/geofences/#{geofence.id}/subscription", %{
          "notify_on_entry" => true,
          "notify_on_exit" => false,
          "throttle_seconds" => 600
        })

      assert %{"subscription" => sub} = json_response(conn, 200)
      assert sub["notify_on_entry"] == true
      assert sub["notify_on_exit"] == false
      assert sub["throttle_seconds"] == 600
    end

    test "GET shows existing subscription", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      put(conn, "/api/v1/geofences/#{geofence.id}/subscription", %{"throttle_seconds" => 100})

      conn2 =
        build_conn()
        |> authed_conn(user)
        |> get("/api/v1/geofences/#{geofence.id}/subscription")

      assert %{"subscription" => sub} = json_response(conn2, 200)
      assert sub["throttle_seconds"] == 100
    end
  end

  describe "opt-outs" do
    test "POST creates opt-out", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn = post(conn, "/api/v1/geofences/#{geofence.id}/opt-out")
      assert json_response(conn, 200)["ok"] == true
    end

    test "POST returns 409 for duplicate opt-out", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      post(conn, "/api/v1/geofences/#{geofence.id}/opt-out")

      conn2 =
        build_conn()
        |> authed_conn(user)
        |> post("/api/v1/geofences/#{geofence.id}/opt-out")

      assert json_response(conn2, 409)
    end

    test "DELETE removes opt-out", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      post(conn, "/api/v1/geofences/#{geofence.id}/opt-out")

      conn2 =
        build_conn()
        |> authed_conn(user)
        |> delete("/api/v1/geofences/#{geofence.id}/opt-out")

      assert json_response(conn2, 200)["ok"] == true
    end

    test "DELETE returns 404 when no opt-out exists", %{conn: conn, user: user} do
      group = create_group(user)
      geofence = create_geofence(group, user)

      conn = delete(conn, "/api/v1/geofences/#{geofence.id}/opt-out")
      assert json_response(conn, 404)
    end
  end
end
