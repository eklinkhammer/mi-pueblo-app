defmodule Fence.Integration.LocationGeofencePipelineTest do
  @moduledoc """
  The core E2E test. Validates the full pipeline:
  location report → Oban geofence check → PostGIS containment →
  state update → Oban push notification → channel broadcast.
  """

  use Fence.IntegrationCase, async: false

  # San Francisco coordinates
  @sf_lat 37.7749
  @sf_lng -122.4194

  # New York coordinates (far from SF)
  @nyc_lat 40.7128
  @nyc_lng -74.0060

  # Oakland coordinates (near SF)
  @oakland_lat 37.8044
  @oakland_lng -122.2712

  describe "location triggers geofence entry + notification broadcast" do
    test "full pipeline: report → check → enter → notify → broadcast", %{conn: conn} do
      # Setup: A & B in a group
      {user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      grant_mutual_visibility(user_a["id"], user_b["id"], group_id)

      # A creates geofence at SF (5km radius)
      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "San Francisco",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # B subscribes to geofence notifications (throttle: 0 for immediate)
      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })
      |> json_response(200)

      # B joins group channel via WebSocket
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A reports location inside the geofence
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0,
        "speed" => 0.0
      })
      |> json_response(200)

      # Drain geofence checks → should broadcast location:updated
      Oban.drain_queue(Oban, queue: :geofence_checks)
      assert_broadcast "location:updated", %{latitude: lat}
      assert_in_delta lat, @sf_lat, 0.001

      # Drain notifications → should broadcast geofence:entered
      Oban.drain_queue(Oban, queue: :notifications)
      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id, event: "entered"}

      # Verify user_geofence_state in DB
      user_a = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")
      state_ids = Fence.Locations.get_user_geofence_ids(user_a.id)
      assert MapSet.member?(state_ids, geofence_id)

      # Verify push_log entry
      import Ecto.Query

      logs =
        Fence.Repo.all(
          from p in Fence.Notifications.PushLog, where: p.geofence_id == ^geofence_id
        )

      assert logs != []
      assert hd(logs).event == "entered"
    end
  end

  describe "location triggers geofence exit" do
    test "user moves out of geofence → exit event", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "San Francisco",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })

      # Pre-seed A as inside the geofence
      user_a = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")

      Fence.Locations.update_geofence_state(
        user_a.id,
        MapSet.new([geofence_id]),
        MapSet.new()
      )

      # B joins group channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A reports location far away (NYC)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      # Drain Oban
      drain_oban()

      # Should see geofence:exited broadcast
      assert_broadcast "geofence:exited", %{geofence_id: ^geofence_id, event: "exited"}

      # Verify state cleared
      state_ids = Fence.Locations.get_user_geofence_ids(user_a.id)
      refute MapSet.member?(state_ids, geofence_id)
    end
  end

  describe "location via WebSocket channel" do
    test "location:update via channel triggers same pipeline", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "San Francisco",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })

      # A joins channel and sends location via WebSocket
      socket_a = connect_user_socket(token_a)
      socket_a = join_group_channel(socket_a, group_id)

      # B also joins to receive broadcasts
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A sends location via channel push
      ref =
        push(socket_a, "location:update", %{
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "accuracy" => 10.0
        })

      assert_reply ref, :ok

      # Drain Oban → full cascade
      drain_oban()

      assert_broadcast "location:updated", %{latitude: lat}
      assert_in_delta lat, @sf_lat, 0.001

      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id}
    end
  end

  describe "multiple geofences, partial containment" do
    test "enters one geofence but not another", %{conn: conn} do
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      # Create SF geofence
      sf_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "SF Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      sf_id = sf_resp["geofence"]["id"]

      # Create Oakland geofence
      oak_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Oakland Zone",
          "latitude" => @oakland_lat,
          "longitude" => @oakland_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      oak_id = oak_resp["geofence"]["id"]

      # B subscribes to both
      for gf_id <- [sf_id, oak_id] do
        conn_b
        |> put("/api/v1/geofences/#{gf_id}/subscription", %{
          "notify_on_entry" => true,
          "notify_on_exit" => true,
          "throttle_seconds" => 0
        })
      end

      # B joins channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # A reports location inside SF only
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Should get entry for SF
      assert_broadcast "geofence:entered", %{geofence_id: ^sf_id}

      # Verify state: inside SF, not Oakland
      user_a = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Alice")
      state_ids = Fence.Locations.get_user_geofence_ids(user_a.id)
      assert MapSet.member?(state_ids, sf_id)
      refute MapSet.member?(state_ids, oak_id)

      # A moves to Oakland (still outside SF's 5km radius from downtown)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @oakland_lat,
        "longitude" => @oakland_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Should get entry for Oakland
      assert_broadcast "geofence:entered", %{geofence_id: ^oak_id}
    end
  end

  # Helper: creates a group with A as admin, B joins via invite
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
