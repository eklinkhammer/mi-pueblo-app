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
