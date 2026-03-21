defmodule Fence.Integration.CrossGroupTest do
  @moduledoc """
  Tests cross-group geofence detection and access control:
  user in two groups triggers events in both, non-members get 403.
  """

  use Fence.IntegrationCase, async: false

  @sf_lat 37.7749
  @sf_lng -122.4194

  describe "user in two groups triggers events in both" do
    test "Alice in Group1 and Group2, entering geofence fires events on both channels", %{
      conn: conn
    } do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      {_carol, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)
      conn_c = authed_conn_from_token(conn, token_c)

      # Alice creates Group1, Bob joins
      group1 = setup_group_with_invite(conn_a, conn_b, "Group1")
      group1_id = group1["id"]

      # Alice creates Group2, Carol joins
      group2 = setup_group_with_invite(conn_a, conn_c, "Group2")
      group2_id = group2["id"]

      # Create geofence in each group at SF
      gf1_resp =
        conn_a
        |> post("/api/v1/groups/#{group1_id}/geofences", %{
          "name" => "SF Zone G1",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      gf2_resp =
        conn_a
        |> post("/api/v1/groups/#{group2_id}/geofences", %{
          "name" => "SF Zone G2",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      gf1_id = gf1_resp["geofence"]["id"]
      gf2_id = gf2_resp["geofence"]["id"]

      # Bob subscribes to Group1 geofence, Carol subscribes to Group2 geofence
      conn_b
      |> put("/api/v1/geofences/#{gf1_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })
      |> json_response(200)

      conn_c
      |> put("/api/v1/geofences/#{gf2_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })
      |> json_response(200)

      # Bob joins Group1 channel, Carol joins Group2 channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group1_id)

      socket_c = connect_user_socket(token_c)
      _socket_c = join_group_channel(socket_c, group2_id)

      # Alice reports location at SF
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Both channels should receive geofence:entered
      assert_broadcast "geofence:entered", %{geofence_id: ^gf1_id}
      assert_broadcast "geofence:entered", %{geofence_id: ^gf2_id}

      # Alice's user_geofence_state should contain both geofence IDs
      alice_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")
      state_ids = Fence.Locations.get_user_geofence_ids(alice_user.id)
      assert MapSet.member?(state_ids, gf1_id)
      assert MapSet.member?(state_ids, gf2_id)
    end
  end

  describe "non-member access control on geofence endpoints" do
    test "non-member gets 403 on GET/POST/PUT/DELETE geofence routes", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_carol, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_c = authed_conn_from_token(conn, token_c)

      # Alice creates a group (Carol is NOT a member)
      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Private Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Alice creates a geofence
      gf_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Private Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 1000.0
        })
        |> json_response(201)

      geofence_id = gf_resp["geofence"]["id"]

      # Carol tries to list geofences -> 403
      conn_c
      |> get("/api/v1/groups/#{group_id}/geofences")
      |> json_response(403)

      # Carol tries to create a geofence -> 403
      conn_c
      |> post("/api/v1/groups/#{group_id}/geofences", %{
        "name" => "Hacked",
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "radius_meters" => 100.0
      })
      |> json_response(403)

      # Carol tries to view geofence -> 403
      conn_c
      |> get("/api/v1/groups/#{group_id}/geofences/#{geofence_id}")
      |> json_response(403)

      # Carol tries to update geofence -> 403
      conn_c
      |> put("/api/v1/groups/#{group_id}/geofences/#{geofence_id}", %{"name" => "Hacked"})
      |> json_response(403)

      # Carol tries to delete geofence -> 403
      conn_c
      |> delete("/api/v1/groups/#{group_id}/geofences/#{geofence_id}")
      |> json_response(403)
    end
  end

  describe "non-member access control on group locations" do
    test "non-member gets 403, member gets 200", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_carol, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_c = authed_conn_from_token(conn, token_c)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Locations Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Carol (non-member) tries to view group locations -> 403
      conn_c
      |> get("/api/v1/groups/#{group_id}/locations")
      |> json_response(403)

      # Alice (member) can view -> 200
      resp =
        conn_a
        |> get("/api/v1/groups/#{group_id}/locations")
        |> json_response(200)

      assert is_list(resp["locations"])
    end
  end

  defp setup_group_with_invite(conn_a, conn_b, name) do
    group_resp =
      conn_a |> post("/api/v1/groups", %{"name" => name}) |> json_response(201)

    group_id = group_resp["group"]["id"]

    invite_resp =
      conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

    conn_b
    |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
    |> json_response(200)

    group_resp["group"]
  end
end
