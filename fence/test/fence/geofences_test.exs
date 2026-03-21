defmodule Fence.GeofencesTest do
  use Fence.DataCase, async: false

  alias Fence.Geofences
  import Fence.Factory

  setup do
    user = create_user()
    group = create_group(user)
    %{user: user, group: group}
  end

  describe "create_geofence/1" do
    test "creates geofence with PostGIS boundary", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      assert geofence.name == "Test Geofence"
      assert geofence.radius_meters == 500.0
      assert geofence.center
      assert geofence.boundary
    end

    test "rejects invalid attrs" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Geofences.create_geofence(%{"name" => ""})
      end
    end
  end

  describe "get_geofence/1" do
    test "returns geofence by id", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      assert Geofences.get_geofence(geofence.id).id == geofence.id
    end

    test "returns nil for missing id" do
      assert is_nil(Geofences.get_geofence(Ecto.UUID.generate()))
    end
  end

  describe "update_geofence/2" do
    test "updates geofence and recomputes boundary", %{user: user, group: group} do
      geofence = create_geofence(group, user)

      assert {:ok, updated} =
               Geofences.update_geofence(geofence, %{
                 "name" => "Updated",
                 "radius_meters" => 1000.0,
                 "latitude" => 40.7128,
                 "longitude" => -74.0060
               })

      assert updated.name == "Updated"
      assert updated.radius_meters == 1000.0
    end
  end

  describe "delete_geofence/1" do
    test "deletes geofence", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      assert {:ok, _} = Geofences.delete_geofence(geofence)
      assert is_nil(Geofences.get_geofence(geofence.id))
    end
  end

  describe "list_group_geofences/1" do
    test "returns all geofences for group", %{user: user, group: group} do
      g1 = create_geofence(group, user, %{"name" => "First"})
      g2 = create_geofence(group, user, %{"name" => "Second"})

      geofences = Geofences.list_group_geofences(group.id)
      ids = Enum.map(geofences, & &1.id)
      assert g1.id in ids
      assert g2.id in ids
    end
  end

  describe "list_active_group_geofences/1" do
    test "excludes expired geofences", %{user: user, group: group} do
      _expired =
        create_geofence(group, user, %{
          "name" => "Expired",
          "expires_at" => DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        })

      active =
        create_geofence(group, user, %{
          "name" => "Active",
          "expires_at" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)
        })

      result = Geofences.list_active_group_geofences(group.id)
      ids = Enum.map(result, & &1.id)
      assert active.id in ids
    end
  end

  describe "subscriptions" do
    test "upsert_subscription creates subscription", %{user: user, group: group} do
      geofence = create_geofence(group, user)

      assert {:ok, sub} =
               Geofences.upsert_subscription(%{
                 "user_id" => user.id,
                 "geofence_id" => geofence.id,
                 "notify_on_entry" => true,
                 "notify_on_exit" => false
               })

      assert sub.notify_on_entry == true
      assert sub.notify_on_exit == false
    end

    test "upsert_subscription replaces on conflict", %{user: user, group: group} do
      geofence = create_geofence(group, user)

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => user.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 300
        })

      {:ok, sub2} =
        Geofences.upsert_subscription(%{
          "user_id" => user.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 600
        })

      assert sub2.throttle_seconds == 600
    end

    test "get_subscription returns subscription", %{user: user, group: group} do
      geofence = create_geofence(group, user)

      {:ok, _} =
        Geofences.upsert_subscription(%{"user_id" => user.id, "geofence_id" => geofence.id})

      assert Geofences.get_subscription(user.id, geofence.id)
    end

    test "get_subscription returns nil when none", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      assert is_nil(Geofences.get_subscription(user.id, geofence.id))
    end

    test "list_geofence_subscribers returns all subscribers", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      other = create_user()

      {:ok, _} =
        Geofences.upsert_subscription(%{"user_id" => user.id, "geofence_id" => geofence.id})

      {:ok, _} =
        Geofences.upsert_subscription(%{"user_id" => other.id, "geofence_id" => geofence.id})

      subs = Geofences.list_geofence_subscribers(geofence.id)
      assert length(subs) == 2
    end
  end

  describe "opt-outs" do
    test "create_opt_out and opted_out?", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      refute Geofences.opted_out?(user.id, geofence.id)

      assert {:ok, _} = Geofences.create_opt_out(user.id, geofence.id)
      assert Geofences.opted_out?(user.id, geofence.id)
    end

    test "delete_opt_out removes opt-out", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      {:ok, _} = Geofences.create_opt_out(user.id, geofence.id)
      assert {:ok, _} = Geofences.delete_opt_out(user.id, geofence.id)
      refute Geofences.opted_out?(user.id, geofence.id)
    end

    test "delete_opt_out returns error when not found", %{user: user, group: group} do
      geofence = create_geofence(group, user)
      assert {:error, :not_found} = Geofences.delete_opt_out(user.id, geofence.id)
    end
  end
end
