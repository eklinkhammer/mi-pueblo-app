defmodule Fence.Integration.GeofenceLifecycleTest do
  use Fence.IntegrationCase, async: false

  describe "create with real PostGIS boundary, visible to members" do
    test "geofence has computed boundary and is visible to group member", %{conn: conn} do
      # A creates group, B joins
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Family"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
      |> json_response(200)

      # A creates geofence
      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Home",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 500.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Verify PostGIS boundary was computed
      geofence = Fence.Geofences.get_geofence(geofence_id)
      assert geofence.boundary != nil

      # B can see the geofence
      list_resp =
        conn_b
        |> get("/api/v1/groups/#{group_id}/geofences")
        |> json_response(200)

      assert length(list_resp["geofences"]) == 1
      assert hd(list_resp["geofences"])["name"] == "Home"
    end
  end

  describe "subscription upsert" do
    test "create and update subscription", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Family"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Home",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 500.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # B creates subscription
      sub_resp =
        conn_b
        |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
          "notify_on_entry" => true,
          "notify_on_exit" => false,
          "throttle_seconds" => 300
        })
        |> json_response(200)

      assert sub_resp["subscription"]["notify_on_entry"] == true
      assert sub_resp["subscription"]["notify_on_exit"] == false
      assert sub_resp["subscription"]["throttle_seconds"] == 300

      # B reads subscription
      get_resp =
        conn_b
        |> get("/api/v1/geofences/#{geofence_id}/subscription")
        |> json_response(200)

      assert get_resp["subscription"]["throttle_seconds"] == 300

      # B updates subscription (upsert)
      updated_resp =
        conn_b
        |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
          "notify_on_entry" => true,
          "notify_on_exit" => true,
          "throttle_seconds" => 0
        })
        |> json_response(200)

      assert updated_resp["subscription"]["notify_on_exit"] == true
      assert updated_resp["subscription"]["throttle_seconds"] == 0
    end
  end

  describe "full CRUD" do
    test "create → update → show → delete geofence", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Family"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Create
      create_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Office",
          "latitude" => 37.7849,
          "longitude" => -122.4094,
          "radius_meters" => 200.0
        })
        |> json_response(201)

      geofence_id = create_resp["geofence"]["id"]
      assert create_resp["geofence"]["name"] == "Office"

      # Update
      update_resp =
        conn_a
        |> put("/api/v1/groups/#{group_id}/geofences/#{geofence_id}", %{
          "name" => "New Office"
        })
        |> json_response(200)

      assert update_resp["geofence"]["name"] == "New Office"

      # Show
      show_resp =
        conn_a
        |> get("/api/v1/groups/#{group_id}/geofences/#{geofence_id}")
        |> json_response(200)

      assert show_resp["geofence"]["name"] == "New Office"

      # Delete
      conn_a
      |> delete("/api/v1/groups/#{group_id}/geofences/#{geofence_id}")
      |> response(204)

      # Verify deleted
      conn_a
      |> get("/api/v1/groups/#{group_id}/geofences/#{geofence_id}")
      |> json_response(404)
    end
  end
end
