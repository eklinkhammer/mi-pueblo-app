defmodule Fence.StatsTest do
  use Fence.DataCase, async: false

  import Fence.Factory

  alias Fence.{Geofences, Groups, Locations, Stats}

  describe "get_user_stats/1" do
    test "returns empty list when user has no home claimed" do
      user = create_user()
      _group = create_group(user)

      assert Stats.get_user_stats(user.id) == []
    end

    test "returns stats with home visit count" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user, %{"name" => "Home"})

      {:ok, _} = Geofences.claim_home(user.id, geofence.id, group.id)

      # Simulate 2 entries to home
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())
      Locations.update_geofence_state(user.id, MapSet.new(), MapSet.new([geofence.id]))
      Locations.update_geofence_state(user.id, MapSet.new([geofence.id]), MapSet.new())

      [stat] = Stats.get_user_stats(user.id)

      assert stat.group_id == group.id
      assert stat.group_name == "Test Group"
      assert stat.home_geofence_name == "Home"
      assert stat.home_visit_count == 2
      assert stat.housemates == []
      assert stat.your_top_geofences == []
    end

    test "returns user's top non-home geofences" do
      user = create_user()
      group = create_group(user)
      home = create_geofence(group, user, %{"name" => "Home"})
      work = create_geofence(group, user, %{"name" => "Work"})
      gym = create_geofence(group, user, %{"name" => "Gym"})

      {:ok, _} = Geofences.claim_home(user.id, home.id, group.id)

      # 3 visits to work
      for _ <- 1..3 do
        Locations.update_geofence_state(user.id, MapSet.new([work.id]), MapSet.new())
        Locations.update_geofence_state(user.id, MapSet.new(), MapSet.new([work.id]))
      end

      # 1 visit to gym
      Locations.update_geofence_state(user.id, MapSet.new([gym.id]), MapSet.new())
      Locations.update_geofence_state(user.id, MapSet.new(), MapSet.new([gym.id]))

      [stat] = Stats.get_user_stats(user.id)

      assert length(stat.your_top_geofences) == 2
      [first, second] = stat.your_top_geofences
      assert first.geofence_name == "Work"
      assert first.visit_count == 3
      assert second.geofence_name == "Gym"
      assert second.visit_count == 1
    end

    test "includes housemates with active visibility" do
      user = create_user(%{"display_name" => "Alice"})
      housemate = create_user(%{"display_name" => "Bob"})
      group = create_group(user)
      home = create_geofence(group, user, %{"name" => "Home"})

      # Add housemate to group
      {:ok, invite} = Groups.get_or_create_invite(group.id, user.id)
      {:ok, _} = Groups.join_by_invite_code(housemate.id, invite.code)
      {:ok, _} = Groups.share_visibility(user.id, group.id, housemate.id)

      # Both claim same home
      {:ok, _} = Geofences.claim_home(user.id, home.id, group.id)
      {:ok, _} = Geofences.claim_home(housemate.id, home.id, group.id)

      [stat] = Stats.get_user_stats(user.id)

      assert length(stat.housemates) == 1
      assert hd(stat.housemates).display_name == "Bob"
    end

    test "excludes housemates without active visibility" do
      user = create_user(%{"display_name" => "Alice"})
      stranger = create_user(%{"display_name" => "Charlie"})
      group = create_group(user)
      home = create_geofence(group, user, %{"name" => "Home"})

      # Add stranger to group, then revoke auto-shared visibility
      {:ok, invite} = Groups.get_or_create_invite(group.id, user.id)
      {:ok, _} = Groups.join_by_invite_code(stranger.id, invite.code)
      {:ok, _} = Groups.revoke_visibility(user.id, group.id, stranger.id)

      {:ok, _} = Geofences.claim_home(user.id, home.id, group.id)
      {:ok, _} = Geofences.claim_home(stranger.id, home.id, group.id)

      [stat] = Stats.get_user_stats(user.id)

      assert stat.housemates == []
    end
  end
end
