defmodule Fence.Integration.NotificationFilteringTest do
  @moduledoc """
  Tests the PushNotificationWorker.send_if_eligible/4 decision tree:
  throttle suppression, blacklisted users, and selective entry/exit flags.
  """

  use Fence.IntegrationCase, async: false

  import Ecto.Query

  @sf_lat 37.7749
  @sf_lng -122.4194

  # Far from SF
  @nyc_lat 40.7128
  @nyc_lng -74.0060

  describe "throttle suppression" do
    test "re-entry within throttle window logs 'throttled', channel broadcast still fires", %{
      conn: conn
    } do
      {alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      share_mutual_visibility(alice["id"], bob["id"], group_id)

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Throttle Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Bob subscribes with a 600-second throttle
      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 600
      })
      |> json_response(200)

      # Bob joins channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # Alice enters geofence (first time)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # First entry: should broadcast and log "sent"
      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id}

      sent_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where: p.geofence_id == ^geofence_id and p.status == "sent"
          )
        )

      assert length(sent_logs) == 1

      # Alice exits (move to NYC)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      assert_broadcast "geofence:exited", %{geofence_id: ^geofence_id}

      # Alice re-enters rapidly (within 600s throttle window)
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Channel broadcast still fires
      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id}

      # But the push log for the re-entry should be "throttled"
      throttled_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where: p.geofence_id == ^geofence_id and p.status == "throttled"
          )
        )

      assert throttled_logs != []
    end
  end

  describe "blacklisted user" do
    test "blacklisted triggering user does not generate push_log, non-blacklisted does", %{
      conn: conn
    } do
      {alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      {carol, token_c, _} = register_via_api(conn, %{"display_name" => "Carol"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)
      conn_c = authed_conn_from_token(conn, token_c)

      # Create group with all three members
      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Blacklist Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
      |> json_response(200)

      invite_resp2 =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_c
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp2["invite"]["code"]})
      |> json_response(200)

      share_mutual_visibility(alice["id"], bob["id"], group_id)
      share_mutual_visibility(alice["id"], carol["id"], group_id)

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Blacklist Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Bob subscribes with Alice blacklisted
      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0,
        "blacklisted_user_ids" => [alice["id"]]
      })
      |> json_response(200)

      # Carol subscribes with empty blacklist
      conn_c
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => true,
        "throttle_seconds" => 0,
        "blacklisted_user_ids" => []
      })
      |> json_response(200)

      # Bob and Carol join channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # Alice enters geofence
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Channel broadcast still fires (blacklist only affects push)
      assert_broadcast "geofence:entered", %{geofence_id: ^geofence_id}

      # Carol should have a push_log entry
      bob_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Bob")
      carol_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Carol")

      carol_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where: p.recipient_id == ^carol_user.id and p.geofence_id == ^geofence_id
          )
        )

      assert length(carol_logs) == 1
      assert hd(carol_logs).status == "sent"

      # Bob should NOT have a push_log entry (blacklisted = skip, no log at all)
      bob_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where: p.recipient_id == ^bob_user.id and p.geofence_id == ^geofence_id
          )
        )

      assert bob_logs == []
    end
  end

  describe "selective notification flags" do
    test "notify_on_entry: false suppresses entry push, allows exit push", %{conn: conn} do
      {alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      share_mutual_visibility(alice["id"], bob["id"], group_id)

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Entry Disabled Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Bob subscribes: entry disabled, exit enabled
      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => false,
        "notify_on_exit" => true,
        "throttle_seconds" => 0
      })
      |> json_response(200)

      bob_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Bob")

      # Alice enters
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # No push_log for Bob on entry (entry notification skipped)
      entry_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where:
              p.recipient_id == ^bob_user.id and
                p.geofence_id == ^geofence_id and
                p.event == "entered"
          )
        )

      assert entry_logs == []

      # Alice exits
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Bob DOES get a push_log for exit
      exit_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where:
              p.recipient_id == ^bob_user.id and
                p.geofence_id == ^geofence_id and
                p.event == "exited"
          )
        )

      assert length(exit_logs) == 1
      assert hd(exit_logs).status == "sent"
    end

    test "notify_on_exit: false suppresses exit push, allows entry push", %{conn: conn} do
      {alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      share_mutual_visibility(alice["id"], bob["id"], group_id)

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Exit Disabled Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Bob subscribes: entry enabled, exit disabled
      conn_b
      |> put("/api/v1/geofences/#{geofence_id}/subscription", %{
        "notify_on_entry" => true,
        "notify_on_exit" => false,
        "throttle_seconds" => 0
      })
      |> json_response(200)

      bob_user = Fence.Repo.get_by(Fence.Accounts.User, display_name: "Bob")

      # Alice enters
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Bob gets entry push_log
      entry_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where:
              p.recipient_id == ^bob_user.id and
                p.geofence_id == ^geofence_id and
                p.event == "entered"
          )
        )

      assert length(entry_logs) == 1
      assert hd(entry_logs).status == "sent"

      # Alice exits
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @nyc_lat,
        "longitude" => @nyc_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Bob does NOT get exit push_log
      exit_logs =
        Fence.Repo.all(
          from(p in Fence.Notifications.PushLog,
            where:
              p.recipient_id == ^bob_user.id and
                p.geofence_id == ^geofence_id and
                p.event == "exited"
          )
        )

      assert exit_logs == []
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
