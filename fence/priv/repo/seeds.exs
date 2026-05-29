# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Idempotent: safe to run multiple times.

alias Fence.{Repo, Accounts, Groups, Geofences, Locations}
alias Fence.Groups.Invite
alias Fence.Locations.{UserGeofenceState, GeofenceEvent}

# ── Idempotency check ──────────────────────────────────────────────
if Accounts.get_user_by_email("alice@test.com") do
  IO.puts("Seed data already exists (alice@test.com found). Skipping.")
else
  # ── Users ──────────────────────────────────────────────────────────
  users_attrs = [
    %{email: "alice@test.com", display_name: "Alice", password: "password123"},
    %{email: "bob@test.com", display_name: "Bob", password: "password123"},
    %{email: "carol@test.com", display_name: "Carol", password: "password123"}
  ]

  [alice, bob, carol] =
    Enum.map(users_attrs, fn attrs ->
      {:ok, user} = Accounts.register_user(attrs)
      user
    end)

  # ── Group ──────────────────────────────────────────────────────────
  {:ok, group} = Groups.create_group(alice, %{"name" => "Test"})

  # ── Invite with known code ────────────────────────────────────────
  now = DateTime.utc_now() |> DateTime.truncate(:second)
  expires_at = DateTime.add(now, 365 * 24 * 3600, :second)

  Repo.insert!(%Invite{
    group_id: group.id,
    created_by_id: alice.id,
    code: "123456",
    expires_at: expires_at
  })

  # ── Bob & Carol join ──────────────────────────────────────────────
  {:ok, _} = Groups.join_by_invite_code(bob.id, "123456")
  {:ok, _} = Groups.join_by_invite_code(carol.id, "123456")

  # ── Activate all visibility pairs ─────────────────────────────────
  for {u1, u2} <- [{alice, bob}, {alice, carol}, {bob, alice}, {bob, carol}, {carol, alice}, {carol, bob}] do
    Groups.grant_visibility(u1.id, group.id, u2.id)
  end

  # ── Geofences ─────────────────────────────────────────────────────
  geofence_attrs = [
    {alice, "Alice's House", 47.7180, -116.9510},
    {bob, "Bob's House", 47.7195, -116.9485},
    {carol, "Carol's House", 47.7165, -116.9535}
  ]

  geofences =
    Enum.map(geofence_attrs, fn {user, name, lat, lng} ->
      {:ok, geofence} =
        Geofences.create_geofence(%{
          "name" => name,
          "radius_meters" => 100.0,
          "latitude" => lat,
          "longitude" => lng,
          "group_id" => group.id,
          "created_by_id" => user.id,
          "expires_at" => expires_at
        })

      {user, geofence, lat, lng}
    end)

  # ── Set home geofence & report location ───────────────────────────
  Enum.each(geofences, fn {user, geofence, lat, lng} ->
    {:ok, _} = Geofences.claim_home(user.id, geofence.id, group.id)

    {:ok, _} =
      Locations.report_location(user.id, %{
        "latitude" => lat,
        "longitude" => lng,
        "accuracy" => 5.0,
        "source" => "foreground"
      })
  end)

  # ── Seed geofence state so users appear "at home" ─────────────────
  state_rows =
    Enum.map(geofences, fn {user, geofence, _lat, _lng} ->
      %{
        id: Ecto.UUID.generate(),
        user_id: user.id,
        geofence_id: geofence.id,
        entered_at: now,
        inserted_at: now,
        updated_at: now
      }
    end)

  Repo.insert_all(UserGeofenceState, state_rows, on_conflict: :nothing)

  # ── Geofence visit history (past 14 days) ────────────────────────
  [{_alice_user, alice_gf, _, _}, {_bob_user, bob_gf, _, _}, {_carol_user, carol_gf, _, _}] =
    geofences

  # {visitor, target_geofence, home_geofence, hours_ago, duration_minutes}
  visits = [
    # Alice visits Bob's House (5 times)
    {alice, bob_gf, alice_gf, 13 * 24, 35},
    {alice, bob_gf, alice_gf, 11 * 24, 25},
    {alice, bob_gf, alice_gf, 8 * 24, 45},
    {alice, bob_gf, alice_gf, 5 * 24, 30},
    {alice, bob_gf, alice_gf, 6, 40},         # 6 hours ago
    # Alice visits Carol's House (3 times)
    {alice, carol_gf, alice_gf, 12 * 24, 50},
    {alice, carol_gf, alice_gf, 7 * 24, 20},
    {alice, carol_gf, alice_gf, 3, 55},        # 3 hours ago
    # Bob visits Alice's House (4 times)
    {bob, alice_gf, bob_gf, 13 * 24, 40},
    {bob, alice_gf, bob_gf, 10 * 24, 30},
    {bob, alice_gf, bob_gf, 6 * 24, 25},
    {bob, alice_gf, bob_gf, 8, 50},            # 8 hours ago
    # Bob visits Carol's House (2 times)
    {bob, carol_gf, bob_gf, 9 * 24, 35},
    {bob, carol_gf, bob_gf, 14, 45},           # 14 hours ago
    # Carol visits Alice's House (6 times)
    {carol, alice_gf, carol_gf, 13 * 24, 30},
    {carol, alice_gf, carol_gf, 11 * 24, 45},
    {carol, alice_gf, carol_gf, 9 * 24, 20},
    {carol, alice_gf, carol_gf, 7 * 24, 55},
    {carol, alice_gf, carol_gf, 4 * 24, 35},
    {carol, alice_gf, carol_gf, 10, 40},       # 10 hours ago
    # Carol visits Bob's House (3 times)
    {carol, bob_gf, carol_gf, 12 * 24, 25},
    {carol, bob_gf, carol_gf, 8 * 24, 50},
    {carol, bob_gf, carol_gf, 4, 30}           # 4 hours ago
  ]

  visit_events =
    Enum.flat_map(visits, fn {visitor, target_gf, home_gf, hours_ago, duration_min} ->
      entered_at =
        now
        |> DateTime.add(-hours_ago * 3600, :second)

      exited_at = DateTime.add(entered_at, duration_min * 60, :second)
      home_at = DateTime.add(exited_at, 600, :second)

      [
        %{
          id: Ecto.UUID.generate(),
          user_id: visitor.id,
          geofence_id: target_gf.id,
          event: "entered",
          inserted_at: entered_at,
          updated_at: entered_at
        },
        %{
          id: Ecto.UUID.generate(),
          user_id: visitor.id,
          geofence_id: target_gf.id,
          event: "exited",
          inserted_at: exited_at,
          updated_at: exited_at
        },
        %{
          id: Ecto.UUID.generate(),
          user_id: visitor.id,
          geofence_id: home_gf.id,
          event: "entered",
          inserted_at: home_at,
          updated_at: home_at
        }
      ]
    end)

  Repo.insert_all(GeofenceEvent, visit_events)
  IO.puts("  Seeded #{length(visit_events)} geofence events (#{length(visits)} visits)")

  # ── Summary ────────────────────────────────────────────────────────
  IO.puts("""

  ============================================
   Seed data created successfully!
  ============================================

   Group: "Test"
   Invite code: 123456

   Users (password: password123):
     - Alice  alice@test.com
     - Bob    bob@test.com
     - Carol  carol@test.com

   Location: Post Falls, Idaho area
  ============================================
  """)
end
