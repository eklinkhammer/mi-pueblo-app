defmodule Fence.LocationsTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Locations
  alias Fence.Workers.GeofenceCheckWorker
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

  describe "get_group_last_locations/2" do
    test "returns latest location per group member filtered by visibility" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      {:ok, _} =
        Locations.report_location(admin.id, %{"latitude" => 37.0, "longitude" => -122.0})

      {:ok, _} =
        Locations.report_location(member.id, %{"latitude" => 40.0, "longitude" => -74.0})

      # Visibility is active by default after join — admin can see both
      locations = Locations.get_group_last_locations(group.id, admin.id)
      assert length(locations) == 2
      user_ids = Enum.map(locations, & &1.user_id) |> MapSet.new()
      assert MapSet.member?(user_ids, admin.id)
      assert MapSet.member?(user_ids, member.id)

      # Revoke visibility — admin can only see their own location
      {:ok, _} = Fence.Groups.revoke_visibility(admin.id, group.id, member.id)
      locations = Locations.get_group_last_locations(group.id, admin.id)
      assert length(locations) == 1
      assert hd(locations).user_id == admin.id
    end

    test "excludes members with sharing_mode set to geofences" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      # Grant mutual visibility
      {:ok, _} = Fence.Groups.share_visibility(admin.id, group.id, member.id)

      # Both report locations
      {:ok, _} =
        Locations.report_location(admin.id, %{"latitude" => 37.0, "longitude" => -122.0})

      {:ok, _} =
        Locations.report_location(member.id, %{"latitude" => 40.0, "longitude" => -74.0})

      # Both visible with default "live" sharing mode
      locations = Locations.get_group_last_locations(group.id, admin.id)
      assert length(locations) == 2

      # Switch member to geofences-only mode
      {:ok, _} = Fence.Groups.update_sharing_mode(member.id, group.id, "geofences")

      # Admin should now only see their own location
      locations = Locations.get_group_last_locations(group.id, admin.id)
      assert length(locations) == 1
      assert hd(locations).user_id == admin.id
    end
  end

  describe "get_group_geofence_presence/2" do
    test "returns geofence presence for visible members" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      # Grant visibility
      {:ok, _} = Fence.Groups.share_visibility(admin.id, group.id, member.id)

      # Create geofence and place member inside it
      geofence = create_geofence(group, admin, %{"name" => "Office"})
      Locations.update_geofence_state(member.id, MapSet.new([geofence.id]), MapSet.new())

      presence = Locations.get_group_geofence_presence(group.id, admin.id)
      assert length(presence) == 1
      entry = hd(presence)
      assert entry.user_id == member.id
      assert entry.display_name == "Member"
      assert entry.geofence_id == geofence.id
      assert entry.geofence_name == "Office"
      assert entry.geofence_center
      assert entry.entered_at
    end

    test "excludes non-visible members" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      # Revoke auto-shared visibility
      {:ok, _} = Fence.Groups.revoke_visibility(admin.id, group.id, member.id)
      geofence = create_geofence(group, admin)
      Locations.update_geofence_state(member.id, MapSet.new([geofence.id]), MapSet.new())

      presence = Locations.get_group_geofence_presence(group.id, admin.id)
      # Admin can only see themselves, and they are not in any geofence
      assert Enum.empty?(presence)
    end

    test "includes both sharing modes" do
      admin = create_user(%{"display_name" => "Admin"})
      member = create_user(%{"display_name" => "Member"})
      group = create_group(admin)

      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)
      {:ok, _} = Fence.Groups.share_visibility(admin.id, group.id, member.id)

      geofence = create_geofence(group, admin)

      # Place both admin (live) and member inside the geofence
      Locations.update_geofence_state(admin.id, MapSet.new([geofence.id]), MapSet.new())
      Locations.update_geofence_state(member.id, MapSet.new([geofence.id]), MapSet.new())

      # Switch member to geofences mode
      {:ok, _} = Fence.Groups.update_sharing_mode(member.id, group.id, "geofences")

      presence = Locations.get_group_geofence_presence(group.id, admin.id)
      assert length(presence) == 2
      modes = Enum.map(presence, & &1.sharing_mode) |> MapSet.new()
      assert MapSet.member?(modes, "live")
      assert MapSet.member?(modes, "geofences")
    end

    test "viewer sees own geofence presence" do
      admin = create_user(%{"display_name" => "Admin"})
      group = create_group(admin)
      geofence = create_geofence(group, admin)

      Locations.update_geofence_state(admin.id, MapSet.new([geofence.id]), MapSet.new())

      presence = Locations.get_group_geofence_presence(group.id, admin.id)
      assert length(presence) == 1
      assert hd(presence).user_id == admin.id
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

    test "process_geofence_event verifies enter event with PostGIS" do
      user = create_user()
      group = create_group(user)

      geofence =
        create_geofence(group, user, %{
          "name" => "SF Zone",
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "radius_meters" => 5000.0
        })

      assert {:ok, %{verified: true}} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => geofence.id,
                 "action" => "entered",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })

      # State update now happens async via GeofenceCheckWorker — drain the job
      assert_enqueued(worker: GeofenceCheckWorker, args: %{"user_id" => user.id})

      # Execute the enqueued job to apply state changes
      [job] = all_enqueued(worker: GeofenceCheckWorker)
      perform_job(GeofenceCheckWorker, job.args)

      # User should now be inside the geofence
      ids = Locations.get_user_geofence_ids(user.id)
      assert MapSet.member?(ids, geofence.id)
    end

    test "process_geofence_event rejects non-member" do
      user = create_user()
      other = create_user()
      group = create_group(other)
      geofence = create_geofence(group, other)

      assert {:error, :forbidden} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => geofence.id,
                 "action" => "entered",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })
    end

    test "process_geofence_event rejects opted-out user" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user)
      {:ok, _} = Fence.Geofences.create_opt_out(user.id, geofence.id)

      assert {:error, :opted_out} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => geofence.id,
                 "action" => "entered",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })
    end

    test "process_geofence_event returns not_found for missing geofence" do
      user = create_user()

      assert {:error, :not_found} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => Ecto.UUID.generate(),
                 "action" => "entered",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })
    end

    test "process_geofence_event rejects invalid action" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user)

      assert {:error, :invalid_action} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => geofence.id,
                 "action" => "invalid",
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })
    end

    test "process_geofence_event rejects nil action" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user)

      assert {:error, :invalid_action} =
               Locations.process_geofence_event(user.id, %{
                 "geofence_id" => geofence.id,
                 "latitude" => 37.7749,
                 "longitude" => -122.4194,
                 "accuracy" => 10.0
               })
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
