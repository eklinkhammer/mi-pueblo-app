defmodule Fence.Workers.PushNotificationWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.{Geofences, Groups, Notifications, Repo}
  alias Fence.Groups.Membership
  alias Fence.Workers.PushNotificationWorker
  import Fence.Factory

  setup do
    :ok
  end

  defp setup_geofence_with_subscriber do
    triggering_user = create_user(%{"display_name" => "Trigger"})
    subscriber = create_user(%{"display_name" => "Subscriber"})
    group = create_group(triggering_user)

    {:ok, invite} = Groups.get_or_create_invite(group.id, triggering_user.id)
    {:ok, _} = Groups.join_by_invite_code(subscriber.id, invite.code)

    geofence = create_geofence(group, triggering_user)

    {:ok, _} =
      Geofences.upsert_subscription(%{
        "user_id" => subscriber.id,
        "geofence_id" => geofence.id,
        "throttle_seconds" => 0
      })

    # Grant mutual visibility so notifications can flow
    {:ok, _} = Groups.grant_visibility(triggering_user.id, group.id, subscriber.id)

    {triggering_user, subscriber, geofence, group}
  end

  describe "perform/1" do
    test "sends notification to eligible subscriber" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end

    test "skips self-notification" do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user)

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => user.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 0
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      # No notification logged since self-notify is skipped
      assert is_nil(Notifications.last_notification_time(user.id, geofence.id))
    end

    test "skips when event type not enabled" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      # Disable exit notifications
      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => subscriber.id,
          "geofence_id" => geofence.id,
          "notify_on_exit" => false,
          "throttle_seconds" => 0
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "exited"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "skips blacklisted user" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => subscriber.id,
          "geofence_id" => geofence.id,
          "blacklisted_user_ids" => [triggering_user.id],
          "throttle_seconds" => 0
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "logs throttled when within throttle window" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => subscriber.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 999_999
        })

      # First notification goes through
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      # Second should be throttled
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })
    end

    test "broadcasts geofence event via PubSub" do
      {triggering_user, _subscriber, geofence, group} = setup_geofence_with_subscriber()

      Phoenix.PubSub.subscribe(Fence.PubSub, "group:#{group.id}")

      perform_job(PushNotificationWorker, %{
        "user_id" => triggering_user.id,
        "geofence_id" => geofence.id,
        "event" => "entered"
      })

      assert_receive %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "geofence:entered"
      }

      assert topic == "group:#{group.id}"
    end

    test "member_joined sends notification to existing members, skips joining user" do
      admin = create_user(%{"display_name" => "Admin"})
      group = create_group(admin)
      joiner = create_user(%{"display_name" => "Joiner"})
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Groups.join_by_invite_code(joiner.id, invite.code)

      # The worker should complete without error
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "type" => "member_joined",
                 "group_id" => group.id,
                 "user_id" => joiner.id
               })
    end

    test "skips geofence notification when visibility not granted" do
      triggering_user = create_user(%{"display_name" => "Trigger"})
      subscriber = create_user(%{"display_name" => "Subscriber"})
      group = create_group(triggering_user)

      {:ok, invite} = Groups.get_or_create_invite(group.id, triggering_user.id)
      {:ok, _} = Groups.join_by_invite_code(subscriber.id, invite.code)

      geofence = create_geofence(group, triggering_user)

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => subscriber.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 0
        })

      # Do NOT grant visibility — pair stays pending

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      # No notification because visibility is pending
      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "handles deleted geofence gracefully" do
      user = create_user()

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => user.id,
                 "geofence_id" => Ecto.UUID.generate(),
                 "event" => "entered"
               })
    end

    test "skips when subscriber has silence_all_notifications enabled" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, geofence.group_id, %{
          "silence_all_notifications" => true
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "skips home notification when subscriber has silence_home_notifications enabled" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      # Set the geofence as triggering user's home
      membership = Groups.get_membership(triggering_user.id, geofence.group_id)

      membership
      |> Membership.set_home_changeset(%{home_geofence_id: geofence.id})
      |> Repo.update!()

      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, geofence.group_id, %{
          "silence_home_notifications" => true
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "household override sends despite silence_all when notify_household is on" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      # Both users share the same home geofence
      for user <- [triggering_user, subscriber] do
        Groups.get_membership(user.id, geofence.group_id)
        |> Membership.set_home_changeset(%{home_geofence_id: geofence.id})
        |> Repo.update!()
      end

      # Subscriber silences all but keeps notify_household on (default)
      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, geofence.group_id, %{
          "silence_all_notifications" => true,
          "notify_household" => true
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      # Notification should still be sent because of household override
      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end
  end
end
