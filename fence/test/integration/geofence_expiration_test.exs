defmodule Fence.Integration.GeofenceExpirationTest do
  @moduledoc """
  Tests ExpireGeofencesWorker and its effects on the containment pipeline.
  """

  use Fence.IntegrationCase, async: false

  import Ecto.Query

  alias Fence.Accounts.User
  alias Fence.Geofences
  alias Fence.Geofences.Geofence
  alias Fence.Locations
  alias Fence.Repo
  alias Fence.Workers.ExpireGeofencesWorker

  @sf_lat 37.7749
  @sf_lng -122.4194

  @oakland_lat 37.8044
  @oakland_lng -122.2712

  describe "ExpireGeofencesWorker deletes expired geofences" do
    test "expired geofence deleted, active one remains", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Expire Group"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      # Create two geofences via API (both get far-future default expiry)
      sf_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "SF Active",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      oak_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Oakland Expired",
          "latitude" => @oakland_lat,
          "longitude" => @oakland_lng,
          "radius_meters" => 3000.0
        })
        |> json_response(201)

      sf_id = sf_resp["geofence"]["id"]
      oak_id = oak_resp["geofence"]["id"]

      # Expire the Oakland geofence by setting expires_at to the past
      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      from(g in Geofence, where: g.id == ^oak_id)
      |> Repo.update_all(set: [expires_at: past])

      # Run the expire worker
      ExpireGeofencesWorker.new(%{}) |> Oban.insert()
      Oban.drain_queue(Oban, queue: :maintenance)

      # Oakland should be deleted
      assert Geofences.get_geofence(oak_id) == nil

      # SF should remain
      assert Geofences.get_geofence(sf_id) != nil

      # HTTP list endpoint confirms
      list_resp =
        conn_a
        |> get("/api/v1/groups/#{group_id}/geofences")
        |> json_response(200)

      names = Enum.map(list_resp["geofences"], & &1["name"])
      assert "SF Active" in names
      refute "Oakland Expired" in names
    end
  end

  describe "expired geofence stops triggering containment" do
    test "location at expired geofence center does not trigger entry", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Will Expire",
          "latitude" => @sf_lat,
          "longitude" => @sf_lng,
          "radius_meters" => 5000.0
        })
        |> json_response(201)

      geofence_id = geofence_resp["geofence"]["id"]

      # Expire it
      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      from(g in Geofence, where: g.id == ^geofence_id)
      |> Repo.update_all(set: [expires_at: past])

      # Bob joins channel
      socket_b = connect_user_socket(token_b)
      _socket_b = join_group_channel(socket_b, group_id)

      # Alice reports location at geofence center
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # location:updated still broadcasts
      assert_broadcast "location:updated", _payload

      # But no geofence:entered (expired geofence excluded from containment query)
      refute_broadcast "geofence:entered", _any, 100

      # No user_geofence_state entries
      alice_user = Repo.get_by(User, display_name: "Alice")
      state_ids = Locations.get_user_geofence_ids(alice_user.id)
      assert MapSet.size(state_ids) == 0
    end
  end

  describe "user inside geofence when it expires" do
    test "expire worker cleans up, subsequent location no longer detects geofence", %{conn: conn} do
      {_alice, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {_bob, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group = setup_group_with_invite(conn_a, conn_b)
      group_id = group["id"]

      geofence_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/geofences", %{
          "name" => "Temp Zone",
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
      |> json_response(200)

      # Alice enters the geofence
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # Verify Alice is inside the geofence
      alice_user = Repo.get_by(User, display_name: "Alice")
      state_ids = Locations.get_user_geofence_ids(alice_user.id)
      assert MapSet.member?(state_ids, geofence_id)

      # Now expire the geofence and run the worker
      past = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      from(g in Geofence, where: g.id == ^geofence_id)
      |> Repo.update_all(set: [expires_at: past])

      ExpireGeofencesWorker.new(%{}) |> Oban.insert()
      Oban.drain_queue(Oban, queue: :maintenance)

      # Geofence should be deleted
      assert Geofences.get_geofence(geofence_id) == nil

      # Alice reports same location again
      conn_a
      |> post("/api/v1/location", %{
        "latitude" => @sf_lat,
        "longitude" => @sf_lng,
        "accuracy" => 10.0
      })
      |> json_response(200)

      drain_oban()

      # The deleted geofence should not appear in containment results
      # The geofence_check_worker will see current_ids as empty,
      # and the old state entry for the deleted geofence will trigger an "exit"
      # but PushNotificationWorker will skip it (geofence is nil)
      new_state_ids = Locations.get_user_geofence_ids(alice_user.id)
      refute MapSet.member?(new_state_ids, geofence_id)
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
