defmodule Fence.Integration.AccountDeletionTest do
  @moduledoc """
  Tests that DELETE /api/v1/me removes the user and all associated data
  via PostgreSQL cascades, nilifies created_by references, and invalidates tokens.
  """

  use Fence.IntegrationCase, async: false

  import Ecto.Query

  alias Fence.{Accounts, Notifications, Repo}

  @sf_lat 37.7749
  @sf_lng -122.4194

  describe "DELETE /api/v1/me" do
    test "cascades deletion across all referencing tables", %{conn: conn} do
      # 1. Register Alice and Bob
      {alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      alice_id = alice["id"]
      bob_id = bob["id"]

      # 2. Create associated data for Alice

      # Device token
      conn_a
      |> post("/api/v1/me/device-token", %{"token" => "fcm-alice-token", "platform" => "ios"})
      |> json_response(200)

      # Share token (no API endpoint — create directly)
      {:ok, _share_token} = Accounts.create_share_token(alice_id)

      # Group — Alice as admin/creator
      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Deletion Test Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Bob joins group via invite
      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
      |> json_response(200)

      # Geofence — Alice creates (auto-creates subscription for creator)
      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Deletion Zone",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Opt-out for Alice
      conn_a
      |> post("/api/v1/geofences/#{geofence_id}/opt-out")
      |> json_response(200)

      # Location report — creates device_location, triggers geofence check jobs
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0,
        "speed" => 0.0
      })
      |> json_response(200)

      # Drain Oban — processes geofence checks, creates user_geofence_state entries
      drain_oban()

      # Member notification preference — Bob observes Alice
      conn_b
      |> put("/api/v1/groups/#{group_id}/member-preferences/#{alice_id}", %{
        "notify" => false,
        "notify_home" => true
      })
      |> json_response(200)

      # Also create a preference where Alice is observer (of Bob)
      conn_a
      |> put("/api/v1/groups/#{group_id}/member-preferences/#{bob_id}", %{
        "notify" => true,
        "notify_home" => false
      })
      |> json_response(200)

      # Push logs — direct insert (one where Alice is recipient, one where Alice is triggering_user)
      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: alice_id,
          triggering_user_id: bob_id,
          geofence_id: geofence_id,
          event: "entered",
          status: "sent"
        })

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: bob_id,
          triggering_user_id: alice_id,
          geofence_id: geofence_id,
          event: "exited",
          status: "sent"
        })

      # Verify data exists before deletion
      assert Repo.exists?(from(u in "users", where: u.id == type(^alice_id, :binary_id)))

      assert Repo.exists?(
               from(dt in "device_tokens", where: dt.user_id == type(^alice_id, :binary_id))
             )

      assert Repo.exists?(
               from(st in "share_tokens", where: st.user_id == type(^alice_id, :binary_id))
             )

      assert Repo.exists?(
               from(m in "memberships", where: m.user_id == type(^alice_id, :binary_id))
             )

      assert Repo.exists?(
               from(dl in "device_locations", where: dl.user_id == type(^alice_id, :binary_id))
             )

      # 3. DELETE /api/v1/me with Alice's token
      resp = conn_a |> delete("/api/v1/me")
      assert resp.status == 204

      # 4. Verify CASCADE DELETE — zero rows for Alice's user_id

      # users
      refute Repo.exists?(from(u in "users", where: u.id == type(^alice_id, :binary_id)))

      # device_tokens
      refute Repo.exists?(
               from(dt in "device_tokens", where: dt.user_id == type(^alice_id, :binary_id))
             )

      # share_tokens
      refute Repo.exists?(
               from(st in "share_tokens", where: st.user_id == type(^alice_id, :binary_id))
             )

      # memberships
      refute Repo.exists?(
               from(m in "memberships", where: m.user_id == type(^alice_id, :binary_id))
             )

      # geofence_subscriptions
      refute Repo.exists?(
               from(gs in "geofence_subscriptions",
                 where: gs.user_id == type(^alice_id, :binary_id)
               )
             )

      # geofence_opt_outs
      refute Repo.exists?(
               from(go in "geofence_opt_outs",
                 where: go.user_id == type(^alice_id, :binary_id)
               )
             )

      # device_locations
      refute Repo.exists?(
               from(dl in "device_locations", where: dl.user_id == type(^alice_id, :binary_id))
             )

      # user_geofence_state
      refute Repo.exists?(
               from(ugs in "user_geofence_state",
                 where: ugs.user_id == type(^alice_id, :binary_id)
               )
             )

      # push_logs (as recipient)
      refute Repo.exists?(
               from(pl in "push_logs", where: pl.recipient_id == type(^alice_id, :binary_id))
             )

      # member_notification_preferences (as observer)
      refute Repo.exists?(
               from(mnp in "member_notification_preferences",
                 where: mnp.observer_id == type(^alice_id, :binary_id)
               )
             )

      # member_notification_preferences (as subject)
      refute Repo.exists?(
               from(mnp in "member_notification_preferences",
                 where: mnp.subject_id == type(^alice_id, :binary_id)
               )
             )

      # visibility_pairs (as user_a or user_b)
      refute Repo.exists?(
               from(vp in "visibility_pairs",
                 where:
                   vp.user_a_id == type(^alice_id, :binary_id) or
                     vp.user_b_id == type(^alice_id, :binary_id)
               )
             )

      # 5. Verify NILIFY — group and geofence still exist with created_by_id == nil
      group =
        Repo.one!(
          from(g in "groups",
            where: g.id == type(^group_id, :binary_id),
            select: %{id: g.id, created_by_id: g.created_by_id}
          )
        )

      assert is_nil(group.created_by_id)

      geofence =
        Repo.one!(
          from(gf in "geofences",
            where: gf.id == type(^geofence_id, :binary_id),
            select: %{id: gf.id, created_by_id: gf.created_by_id}
          )
        )

      assert is_nil(geofence.created_by_id)

      # push_logs where Alice was triggering_user — row still exists, triggering_user_id nilified
      bob_log =
        Repo.one!(
          from(pl in "push_logs",
            where: pl.recipient_id == type(^bob_id, :binary_id) and pl.event == "exited",
            select: %{triggering_user_id: pl.triggering_user_id}
          )
        )

      assert is_nil(bob_log.triggering_user_id)

      # 6. Verify token invalidation — GET /me with old token returns 401
      resp = conn_a |> get("/api/v1/me")
      assert json_response(resp, 401)
    end
  end
end
