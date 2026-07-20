defmodule Fence.Integration.MultiUserRealtimeTest do
  use Fence.IntegrationCase, async: false

  @sf_lat 37.7749
  @sf_lng -122.4194

  describe "two users, one moves, other sees update" do
    test "B receives location:updated when A sends location", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      # Both join group channel
      socket_a = connect_user_socket(token_a)
      socket_a = join_group_channel(socket_a, group_id)

      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A sends location via channel
      ref =
        push(socket_a, "location:update", %{
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "accuracy" => 15.0,
          "speed" => 2.5
        })

      assert_reply ref, :ok

      # Drain Oban so GeofenceCheckWorker broadcasts
      drain_oban()

      # B should see location:updated broadcast
      assert_broadcast "location:updated", payload
      assert payload.display_name == "Alice"
      assert_in_delta payload.latitude, @sf_lat, 0.001
      assert_in_delta payload.longitude, @sf_lng, 0.001
    end
  end

  describe "presence state on join" do
    test "second user sees first user in presence_state", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      # A joins first
      socket_a = connect_user_socket(token_a)
      _socket_a = join_group_channel(socket_a, group_id)

      # A receives presence_state push (contains only themselves initially)
      assert_push "presence_state", _presence_a

      # B joins — should receive presence_state containing A
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      assert_push "presence_state", presence_b
      # presence_b should have at least Alice's entry
      assert map_size(presence_b) >= 1
    end
  end

  describe "broadcast isolation across groups" do
    test "broadcasts only go to the relevant group channel", %{conn: conn} do
      # A is in both groups, B in group1 only, C in group2 only
      {user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      {_user_c, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)
      conn_c = authed_conn_from_token(conn, token_c)

      # Upgrade Alice so she can create multiple groups
      upgrade_tier(user_a["id"])

      # A creates group1, B joins
      group1 = setup_group_with_invite(conn_a, conn_b)
      group1_id = group1["id"]

      # A creates group2, C joins
      group2_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Group 2"}) |> json_response(201)

      group2_id = group2_resp["group"]["id"]

      invite2_resp =
        conn_a |> post("/api/v1/groups/#{group2_id}/invites") |> json_response(201)

      conn_c
      |> post("/api/v1/groups/join", %{"invite_code" => invite2_resp["invite"]["code"]})
      |> json_response(200)

      # B joins group1 channel, C joins group2 channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group1_id)

      socket_c = connect_user_socket(token_c)
      _socket_c = join_group_channel(socket_c, group2_id)

      # A reports location via HTTP
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Both group channels should get location:updated (A is in both groups)
      # B sees it on group1
      assert_broadcast "location:updated", %{display_name: "Alice"}
      # C sees it on group2
      assert_broadcast "location:updated", %{display_name: "Alice"}

      # Now test that B does NOT see broadcasts meant for group2 only
      # We verify by checking no extra unexpected broadcasts arrive
      refute_broadcast "location:updated", _extra, 100
    end
  end

  defp setup_group_with_invite(conn_a, conn_b) do
    group_resp =
      conn_a |> post("/api/v1/groups", %{"name" => "Test Group"}) |> json_response(201)

    group_id = group_resp["group"]["id"]

    invite_resp =
      conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

    conn_b
    |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
    |> json_response(200)

    group_resp["group"]
  end
end
