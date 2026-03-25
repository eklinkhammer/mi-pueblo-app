defmodule Fence.LocationsTest do
  use Fence.DataCase, async: false

  alias Fence.Locations
  import Fence.Factory

  describe "report_location/2" do
    test "creates device location" do
      user = create_user()

      assert {:ok, location} =
               Locations.report_location(user.id, %{
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })

      assert location.user_id == user.id
      assert location.point
      assert location.accuracy == 10.0
    end

    test "rejects invalid location" do
      assert {:error, _} = Locations.report_location(nil, %{})
    end
  end

  describe "get_last_location/1" do
    test "returns a location for user with locations" do
      user = create_user()

      {:ok, _} =
        Locations.report_location(user.id, %{
          "latitude" => 37.0,
          "longitude" => -122.0
        })

      last = Locations.get_last_location(user.id)
      assert last
      assert last.user_id == user.id
    end

    test "returns nil when no locations" do
      user = create_user()
      assert is_nil(Locations.get_last_location(user.id))
    end
  end

  describe "get_group_last_locations/1" do
    test "returns latest location per group member" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      {:ok, _} =
        Locations.report_location(admin.id, %{"latitude" => 37.0, "longitude" => -122.0})

      {:ok, _} =
        Locations.report_location(member.id, %{"latitude" => 40.0, "longitude" => -74.0})

      locations = Locations.get_group_last_locations(group.id)
      assert length(locations) == 2
      user_ids = Enum.map(locations, & &1.user_id) |> MapSet.new()
      assert MapSet.member?(user_ids, admin.id)
      assert MapSet.member?(user_ids, member.id)
    end
  end

  describe "geofence state" do
    test "get_user_geofence_ids returns empty set initially" do
      user = create_user()
      assert MapSet.size(Locations.get_user_geofence_ids(user.id)) == 0
    end

    test "update_geofence_state adds and removes entries" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user)

      # Enter
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)

      # Exit
      Locations.update_geofence_state(user.id, MapSet.new(), MapSet.new([geofence.id]))
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.size(ids) == 0
    end

    test "find_containing_geofences with ST_Contains" do
      user = create_user()
      group = create_group(user)

      # Create geofence centered on SF
      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      # Report location inside the geofence (SF)
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      containing = Locations.find_containing_geofences(user.id, location.id)
      assert MapSet.member?(containing, geofence.id)
    end

    test "find_containing_geofences excludes distant points" do
      user = create_user()
      group = create_group(user)

      _geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 500.0
        })

      # Report location in NYC (far away)
      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 40.7128,
          "longitude" => -74.0060
        })

      containing = Locations.find_containing_geofences(user.id, location.id)
      assert MapSet.size(containing) == 0
    end

    test "find_containing_geofences excludes opted-out geofences" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      {:ok, _} = Fence.Geofences.create_opt_out(user.id, geofence.id)

      {:ok, location} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194
        })

      containing = Locations.find_containing_geofences(user.id, location.id)
      refute MapSet.member?(containing, geofence.id)
    end
  end
end
