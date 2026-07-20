defmodule Fence.Workers.GeofenceCheckWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Locations
  alias Fence.Workers.GeofenceCheckWorker
  import Fence.Factory

  describe "perform/1" do
    test "detects geofence entry" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      # Report location inside geofence
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      assert :ok =
               perform_job(GeofenceCheckWorker, %{
                 "user_id" => user.id,
                 "location_id" => location.id
               })

      # User should now be inside the geofence
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)
    end

    test "detects geofence exit" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      # Manually set user inside geofence
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())

      # Report location far away (NYC)
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 40.7128,
          "longitude" => -74.0060
        })

      assert :ok =
               perform_job(GeofenceCheckWorker, %{
                 "user_id" => user.id,
                 "location_id" => location.id
               })

      ids = Locations.get_user_geofence_ids(user.id)
      refute MapSet.member?(ids, geofence.id)
    end

    test "no change when staying inside geofence" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      # Already inside
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())

      # Report location still inside
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7750,
          "longitude" => -122.4195
        })

      assert :ok =
               perform_job(GeofenceCheckWorker, %{
                 "user_id" => user.id,
                 "location_id" => location.id
               })

      # Still inside
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)
    end

    test "broadcasts location update to group channels" do
      user = create_user()
      group = create_group(user)

      Phoenix.PubSub.subscribe(Fence.PubSub, "group:#{group.id}")

      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id
      })

      assert_receive %Phoenix.Socket.Broadcast{
        event: "location:updated",
        payload: %{user_id: uid}
      }

      assert uid == user.id
    end

    test "broadcasts location update for background source" do
      user = create_user()
      group = create_group(user)

      Phoenix.PubSub.subscribe(Fence.PubSub, "group:#{group.id}")

      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "source" => "background"
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id,
        "source" => "background"
      })

      assert_receive %Phoenix.Socket.Broadcast{
        event: "location:updated",
        payload: %{user_id: uid}
      }

      assert uid == user.id
    end
  end

  describe "apply_ema/4" do
    setup do
      # Clear ETS entries for test isolation
      :ets.delete_all_objects(:geofence_ema)
      :ok
    end

    test "first reading returns raw value" do
      user_id = Ecto.UUID.generate()
      {lat, lng} = GeofenceCheckWorker.apply_ema(user_id, 37.7749, -122.4194, 10.0)
      assert_in_delta lat, 37.7749, 0.0001
      assert_in_delta lng, -122.4194, 0.0001
    end

    test "accurate reading (low accuracy value) moves EMA significantly" do
      user_id = Ecto.UUID.generate()
      # First reading at origin
      GeofenceCheckWorker.apply_ema(user_id, 37.0, -122.0, 10.0)
      # Second accurate reading at a different point (accuracy=10m → alpha≈1.0)
      {lat, lng} = GeofenceCheckWorker.apply_ema(user_id, 38.0, -123.0, 10.0)
      # Should move almost entirely to new position
      assert_in_delta lat, 38.0, 0.01
      assert_in_delta lng, -123.0, 0.01
    end

    test "noisy reading (high accuracy value) barely shifts EMA" do
      user_id = Ecto.UUID.generate()
      # First reading at origin
      GeofenceCheckWorker.apply_ema(user_id, 37.0, -122.0, 10.0)
      # Second noisy reading at a different point (accuracy=200m → alpha=0.1)
      {lat, lng} = GeofenceCheckWorker.apply_ema(user_id, 38.0, -123.0, 200.0)
      # Should barely move from the first position
      assert_in_delta lat, 37.1, 0.01
      assert_in_delta lng, -122.1, 0.01
    end
  end

  describe "accuracy-based filtering" do
    test "skips geofence when accuracy exceeds radius" do
      user = create_user()
      group = create_group(user)

      _geofence =
        create_geofence(group, user, %{
          "name" => "Small Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 100.0
        })

      # Report location with very poor accuracy (500m) inside geofence
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 500.0
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id
      })

      # Should NOT detect entry because accuracy (500m) > radius (100m)
      ids = Locations.get_user_geofence_ids(user.id)
      refute MapSet.member?(ids, _geofence.id)
    end

    test "detects geofence entry with good accuracy" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "Small Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 100.0
        })

      # Report location with good accuracy (10m) inside geofence
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      perform_job(GeofenceCheckWorker, %{
        "user_id" => user.id,
        "location_id" => location.id
      })

      # Should detect entry because accuracy (10m) < radius (100m)
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)
    end
  end
end
