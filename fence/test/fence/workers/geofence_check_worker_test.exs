defmodule Fence.Workers.GeofenceCheckWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Workers.GeofenceCheckWorker
  alias Fence.Locations
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
  end
end
