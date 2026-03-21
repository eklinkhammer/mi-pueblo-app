defmodule Fence.Workers.ExpireGeofencesWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Workers.ExpireGeofencesWorker
  alias Fence.Geofences
  import Fence.Factory

  describe "perform/1" do
    test "deletes expired geofences" do
      user = create_user()
      group = create_group(user)

      expired =
        create_geofence(group, user, %{
          "name" => "Expired",
          "expires_at" => DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        })

      assert :ok = perform_job(ExpireGeofencesWorker, %{})
      assert is_nil(Geofences.get_geofence(expired.id))
    end

    test "preserves future-expiry geofences" do
      user = create_user()
      group = create_group(user)

      active =
        create_geofence(group, user, %{
          "name" => "Active",
          "expires_at" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)
        })

      assert :ok = perform_job(ExpireGeofencesWorker, %{})
      assert Geofences.get_geofence(active.id)
    end

    test "handles no expired geofences" do
      assert :ok = perform_job(ExpireGeofencesWorker, %{})
    end
  end
end
