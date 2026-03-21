defmodule Fence.Geofences.MergeEngineTest do
  use Fence.DataCase, async: false

  alias Fence.Geofences.{MergedGeofence, MergeEngine}
  import Fence.Factory
  import Ecto.Query

  describe "merge_group_geofences/1" do
    test "merges overlapping geofences into one merged record" do
      user = create_user()
      group = create_group(user)

      # Two overlapping geofences in SF (same center, close enough)
      _g1 =
        create_geofence(group, user, %{
          "name" => "SF-1",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 1000.0
        })

      _g2 =
        create_geofence(group, user, %{
          "name" => "SF-2",
          "latitude" => 37.7750,
          "longitude" => -122.4195,
          "radius_meters" => 1000.0
        })

      assert {:ok, _} = MergeEngine.merge_group_geofences(group.id)

      merged =
        from(mg in MergedGeofence, where: mg.group_id == ^group.id)
        |> Repo.all()

      assert length(merged) == 1
      assert hd(merged).boundary
    end

    test "does not merge non-overlapping geofences" do
      user = create_user()
      group = create_group(user)

      # SF and NYC - far apart, should not overlap
      _sf =
        create_geofence(group, user, %{
          "name" => "SF",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 500.0
        })

      _nyc =
        create_geofence(group, user, %{
          "name" => "NYC",
          "latitude" => 40.7128,
          "longitude" => -74.0060,
          "radius_meters" => 500.0
        })

      assert {:ok, _} = MergeEngine.merge_group_geofences(group.id)

      merged =
        from(mg in MergedGeofence, where: mg.group_id == ^group.id)
        |> Repo.all()

      # No merged records since no overlapping pairs with 2+ members
      assert merged == []
    end

    test "clears existing merged geofences before re-merging" do
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

      {:ok, _} = MergeEngine.merge_group_geofences(group.id)
      {:ok, _} = MergeEngine.merge_group_geofences(group.id)

      merged =
        from(mg in MergedGeofence, where: mg.group_id == ^group.id)
        |> Repo.all()

      assert length(merged) == 1
    end

    test "handles single geofence (no merge needed)" do
      user = create_user()
      group = create_group(user)
      _g = create_geofence(group, user)

      assert {:ok, _} = MergeEngine.merge_group_geofences(group.id)

      merged =
        from(mg in MergedGeofence, where: mg.group_id == ^group.id)
        |> Repo.all()

      assert merged == []
    end

    test "handles empty group (no geofences)" do
      user = create_user()
      group = create_group(user)
      assert {:ok, _} = MergeEngine.merge_group_geofences(group.id)
    end
  end
end
