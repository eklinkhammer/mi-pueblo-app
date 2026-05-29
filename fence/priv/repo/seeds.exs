# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Idempotent: safe to run multiple times.

alias Fence.{Repo, Accounts, Groups, Geofences, Locations}
alias Fence.Groups.Invite
alias Fence.Locations.UserGeofenceState

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
