defmodule Fence.Workers.DwellTimeWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Locations
  alias Fence.Locations.PendingGeofenceTransition
  alias Fence.Repo
  alias Fence.Workers.{DwellTimeWorker, GeofenceCheckWorker}
  import Fence.Factory

  describe "dwell time system" do
    setup do
      # Override config to enable dwell time for these tests
      original = Application.get_env(:fence, :geofence_dwell)
      Application.put_env(:fence, :geofence_dwell, entry_seconds: 30, exit_seconds: 60)
      on_exit(fn -> Application.put_env(:fence, :geofence_dwell, original) end)

      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "Test Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      %{user: user, group: group, geofence: geofence}
    end

    test "entry creates pending transition instead of immediate state change", %{
      user: user,
      geofence: geofence
    } do
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id
      })

      # User should NOT be inside the geofence yet (pending dwell)
      ids = Locations.get_user_geofence_ids(user.id)
      refute MapSet.member?(ids, geofence.id)

      # But a pending transition should exist
      pending = Repo.one(PendingGeofenceTransition)
      assert pending != nil
      assert pending.user_id == user.id
      assert pending.geofence_id == geofence.id
      assert pending.event == "entered"

      # And a DwellTimeWorker job should be enqueued
      assert_enqueued(worker: DwellTimeWorker)
    end

    test "DwellTimeWorker commits pending entry", %{user: user, geofence: geofence} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create a pending transition directly
      %PendingGeofenceTransition{}
      |> PendingGeofenceTransition.changeset(%{
        user_id: user.id,
        geofence_id: geofence.id,
        event: "entered",
        first_seen_at: now,
        last_confirmed_at: now
      })
      |> Repo.insert!()

      # Execute the dwell time worker
      perform_job(DwellTimeWorker, %{
        "user_id" => user.id,
        "geofence_id" => geofence.id
      })

      # State should now be committed
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)

      # Pending transition should be cleaned up
      assert Repo.one(PendingGeofenceTransition) == nil
    end

    test "DwellTimeWorker commits pending exit", %{user: user, geofence: geofence} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # User is currently inside the geofence
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)

      # Create a pending "exited" transition
      %PendingGeofenceTransition{}
      |> PendingGeofenceTransition.changeset(%{
        user_id: user.id,
        geofence_id: geofence.id,
        event: "exited",
        first_seen_at: now,
        last_confirmed_at: now
      })
      |> Repo.insert!()

      # Execute the dwell time worker
      perform_job(DwellTimeWorker, %{
        "user_id" => user.id,
        "geofence_id" => geofence.id
      })

      # User should no longer be inside the geofence
      ids = Locations.get_user_geofence_ids(user.id)
      refute MapSet.member?(ids, geofence.id)

      # Pending transition should be cleaned up
      assert Repo.one(PendingGeofenceTransition) == nil
    end

    test "rapid in/out cancels pending transition", %{user: user, geofence: geofence} do
      # First report: inside geofence → creates pending "entered"
      {:ok, loc_inside} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => loc_inside.id
      })

      # Verify pending transition exists
      assert Repo.one(PendingGeofenceTransition) != nil

      # Second report: outside geofence → should cancel pending "entered"
      {:ok, loc_outside} =
        Locations.report_location(user.id, %{
          "latitude" => 40.7128,
          "longitude" => -74.0060
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => loc_outside.id
      })

      # Pending transition should be gone (cancelled by opposite direction)
      assert Repo.one(PendingGeofenceTransition) == nil

      # User should NOT be inside the geofence
      ids = Locations.get_user_geofence_ids(user.id)
      refute MapSet.member?(ids, geofence.id)
    end

    test "DwellTimeWorker discards contradicted transition", %{
      user: user,
      geofence: geofence
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # User is already inside the geofence
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())

      # Create a pending "entered" transition (contradicted — already inside)
      %PendingGeofenceTransition{}
      |> PendingGeofenceTransition.changeset(%{
        user_id: user.id,
        geofence_id: geofence.id,
        event: "entered",
        first_seen_at: now,
        last_confirmed_at: now
      })
      |> Repo.insert!()

      perform_job(DwellTimeWorker, %{
        "user_id" => user.id,
        "geofence_id" => geofence.id
      })

      # Pending should be cleaned up
      assert Repo.one(PendingGeofenceTransition) == nil
      # State should be unchanged (still inside)
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)
    end
  end

  describe "with dwell_time=0 (default test config)" do
    test "entry is committed immediately" do
      user = create_user()
      group = create_group(user)

      _geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id
      })

      # With dwell=0, state change is immediate
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, _geofence.id)
    end
  end
end
