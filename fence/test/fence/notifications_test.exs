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

  describe "upsert_member_notification_preference/1" do
    test "creates a new preference" do
      {observer, geofence} = create_geofence_for_test()
      subject = create_user()

      assert {:ok, pref} =
               Notifications.upsert_member_notification_preference(%{
                 observer_id: observer.id,
                 subject_id: subject.id,
                 group_id: geofence.group_id,
                 notify: false,
                 notify_home: false
               })

      assert pref.observer_id == observer.id
      assert pref.notify == false
      assert pref.notify_home == false
    end

    test "upserts on conflict (same observer/subject/group)" do
      {observer, geofence} = create_geofence_for_test()
      subject = create_user()

      attrs = %{
        observer_id: observer.id,
        subject_id: subject.id,
        group_id: geofence.group_id,
        notify: true,
        notify_home: true
      }

      {:ok, _} = Notifications.upsert_member_notification_preference(attrs)

      {:ok, updated} =
        Notifications.upsert_member_notification_preference(%{attrs | notify: false})

      assert updated.notify == false
      assert updated.notify_home == true
    end
  end

  describe "list_member_notification_preferences/2" do
    test "returns prefs for observer in group" do
      {observer, geofence} = create_geofence_for_test()
      subject1 = create_user()
      subject2 = create_user()

      Notifications.upsert_member_notification_preference(%{
        observer_id: observer.id,
        subject_id: subject1.id,
        group_id: geofence.group_id,
        notify: false
      })

      Notifications.upsert_member_notification_preference(%{
        observer_id: observer.id,
        subject_id: subject2.id,
        group_id: geofence.group_id,
        notify: true
      })

      prefs = Notifications.list_member_notification_preferences(observer.id, geofence.group_id)
      assert length(prefs) == 2
    end

    test "returns empty when no prefs exist" do
      {observer, geofence} = create_geofence_for_test()

      assert [] ==
               Notifications.list_member_notification_preferences(observer.id, geofence.group_id)
    end
  end

  describe "get_member_notification_preferences_for_subject/3" do
    test "batch-loads prefs for multiple observers" do
      {observer1, geofence} = create_geofence_for_test()
      observer2 = create_user()
      subject = create_user()

      Notifications.upsert_member_notification_preference(%{
        observer_id: observer1.id,
        subject_id: subject.id,
        group_id: geofence.group_id,
        notify: false
      })

      Notifications.upsert_member_notification_preference(%{
        observer_id: observer2.id,
        subject_id: subject.id,
        group_id: geofence.group_id,
        notify: true
      })

      prefs =
        Notifications.get_member_notification_preferences_for_subject(
          [observer1.id, observer2.id],
          subject.id,
          geofence.group_id
        )

      assert length(prefs) == 2
    end
  end
end
