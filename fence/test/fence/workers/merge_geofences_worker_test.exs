defmodule Fence.Workers.MergeGeofencesWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Workers.MergeGeofencesWorker
  import Fence.Factory

  describe "perform/1" do
    test "delegates to MergeEngine" do
      user = create_user()
      group = create_group(user)

      _g1 =
        create_geofence(group, user, %{
          "name" => "A",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 1000.0
        })

      _g2 =
        create_geofence(group, user, %{
          "name" => "B",
          "latitude" => 37.7750,
          "longitude" => -122.4195,
          "radius_meters" => 1000.0
        })

      assert :ok = perform_job(MergeGeofencesWorker, %{"group_id" => group.id})
    end

    test "handles group with no geofences" do
      user = create_user()
      group = create_group(user)
      assert :ok = perform_job(MergeGeofencesWorker, %{"group_id" => group.id})
    end
  end
end
