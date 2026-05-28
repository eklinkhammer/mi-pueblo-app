defmodule Fence.NotificationsTest do
  use Fence.DataCase, async: false

  alias Fence.Notifications
  import Fence.Factory

  defp create_geofence_for_test do
    user = create_user()
    group = create_group(user)
    geofence = create_geofence(group, user)
    {user, geofence}
  end

  describe "log_push/1" do
    test "creates a push log entry" do
      user = create_user()

      assert {:ok, log} =
               Notifications.log_push(%{
                 recipient_id: user.id,
                 event: "entered",
                 status: "sent"
               })

      assert log.recipient_id == user.id
      assert log.event == "entered"
      assert log.status == "sent"
    end

    test "rejects invalid event" do
      user = create_user()

      assert {:error, changeset} =
               Notifications.log_push(%{recipient_id: user.id, event: "invalid"})

      assert %{event: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "last_notification_time/2" do
    test "returns the last sent notification time" do
      {user, geofence} = create_geofence_for_test()

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      assert Notifications.last_notification_time(user.id, geofence.id)
    end

    test "returns nil when no notifications" do
      {user, geofence} = create_geofence_for_test()
      assert is_nil(Notifications.last_notification_time(user.id, geofence.id))
    end

    test "ignores throttled notifications" do
      {user, geofence} = create_geofence_for_test()

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "throttled"
        })

      assert is_nil(Notifications.last_notification_time(user.id, geofence.id))
    end
  end

  describe "list_geofence_activity/3" do
    test "returns sent push logs with user names" do
      {user, geofence} = create_geofence_for_test()
      other = create_user(%{"display_name" => "Alice"})

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          triggering_user_id: other.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      results = Notifications.list_geofence_activity(geofence.id, [other.id])
      assert [%{event: "entered", user_name: "Alice"}] = results
    end

    test "excludes throttled and failed logs" do
      {user, geofence} = create_geofence_for_test()
      other = create_user(%{"display_name" => "Bob"})

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          triggering_user_id: other.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "throttled"
        })

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          triggering_user_id: other.id,
          geofence_id: geofence.id,
          event: "exited",
          status: "failed"
        })

      results = Notifications.list_geofence_activity(geofence.id, [other.id])
      assert results == []
    end

    test "filters by visible user ids" do
      {user, geofence} = create_geofence_for_test()
      visible = create_user(%{"display_name" => "Visible"})
      hidden = create_user(%{"display_name" => "Hidden"})

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          triggering_user_id: visible.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          triggering_user_id: hidden.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      results = Notifications.list_geofence_activity(geofence.id, [visible.id])
      assert length(results) == 1
      assert hd(results).user_name == "Visible"
    end

    test "deduplicates per-recipient rows" do
      {_user, geofence} = create_geofence_for_test()
      triggering = create_user(%{"display_name" => "Trig"})
      recipient1 = create_user()
      recipient2 = create_user()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Same event logged for two recipients at the same time
      Fence.Repo.insert!(%Fence.Notifications.PushLog{
        recipient_id: recipient1.id,
        triggering_user_id: triggering.id,
        geofence_id: geofence.id,
        event: "entered",
        status: "sent",
        inserted_at: now
      })

      Fence.Repo.insert!(%Fence.Notifications.PushLog{
        recipient_id: recipient2.id,
        triggering_user_id: triggering.id,
        geofence_id: geofence.id,
        event: "entered",
        status: "sent",
        inserted_at: now
      })

      results = Notifications.list_geofence_activity(geofence.id, [triggering.id])
      assert length(results) == 1
    end

    test "returns empty list when no activity" do
      {_user, geofence} = create_geofence_for_test()
      results = Notifications.list_geofence_activity(geofence.id, [])
      assert results == []
    end

    test "respects limit parameter" do
      {user, geofence} = create_geofence_for_test()
      other = create_user(%{"display_name" => "Limiter"})

      for i <- 1..5 do
        ts = DateTime.utc_now() |> DateTime.add(-i, :second) |> DateTime.truncate(:second)

        Fence.Repo.insert!(%Fence.Notifications.PushLog{
          recipient_id: user.id,
          triggering_user_id: other.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent",
          inserted_at: ts
        })
      end

      results = Notifications.list_geofence_activity(geofence.id, [other.id], 3)
      assert length(results) == 3
    end

    test "orders by most recent first" do
      {user, geofence} = create_geofence_for_test()
      other = create_user(%{"display_name" => "Chrono"})

      old_time = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
      new_time = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

      Fence.Repo.insert!(%Fence.Notifications.PushLog{
        recipient_id: user.id,
        triggering_user_id: other.id,
        geofence_id: geofence.id,
        event: "entered",
        status: "sent",
        inserted_at: old_time
      })

      Fence.Repo.insert!(%Fence.Notifications.PushLog{
        recipient_id: user.id,
        triggering_user_id: other.id,
        geofence_id: geofence.id,
        event: "exited",
        status: "sent",
        inserted_at: new_time
      })

      [first, second] = Notifications.list_geofence_activity(geofence.id, [other.id])
      assert DateTime.compare(first.inserted_at, second.inserted_at) == :gt
    end
  end

  describe "should_throttle?/3" do
    test "returns false when no previous notification" do
      {user, geofence} = create_geofence_for_test()
      refute Notifications.should_throttle?(user.id, geofence.id, 300)
    end

    test "returns true within throttle window" do
      {user, geofence} = create_geofence_for_test()

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      # Large throttle window - should be throttled
      assert Notifications.should_throttle?(user.id, geofence.id, 999_999)
    end

    test "returns false with zero throttle" do
      {user, geofence} = create_geofence_for_test()

      {:ok, _} =
        Notifications.log_push(%{
          recipient_id: user.id,
          geofence_id: geofence.id,
          event: "entered",
          status: "sent"
        })

      refute Notifications.should_throttle?(user.id, geofence.id, 0)
    end
  end
end
