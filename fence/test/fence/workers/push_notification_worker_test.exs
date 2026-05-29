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
    {:ok, _} = Groups.share_visibility(triggering_user.id, group.id, subscriber.id)

    {triggering_user, subscriber, geofence, group}
  end

  defp claim_home(user, group, geofence) do
    Groups.get_membership(user.id, group.id)
    |> Membership.set_home_changeset(%{home_geofence_id: geofence.id})
    |> Repo.update!()
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
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      Phoenix.PubSub.subscribe(Fence.PubSub, "group:#{group.id}")

      perform_job(PushNotificationWorker, %{
        "user_id" => triggering_user.id,
        "geofence_id" => geofence.id,
        "event" => "entered"
      })

      assert_receive %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "geofence:entered",
        payload: payload
      }

      assert topic == "group:#{group.id}"
      assert is_number(payload.geofence_latitude)
      assert is_number(payload.geofence_longitude)
      assert payload.sharing_mode == "live"
      assert is_list(payload.visible_to)
      assert subscriber.id in payload.visible_to
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

    test "skips geofence notification when visibility revoked" do
      triggering_user = create_user(%{"display_name" => "Trigger"})
      subscriber = create_user(%{"display_name" => "Subscriber"})
      group = create_group(triggering_user)

      {:ok, invite} = Groups.get_or_create_invite(group.id, triggering_user.id)
      {:ok, _} = Groups.join_by_invite_code(subscriber.id, invite.code)

      # Revoke auto-shared visibility
      {:ok, _} = Groups.revoke_visibility(triggering_user.id, group.id, subscriber.id)

      geofence = create_geofence(group, triggering_user)

      {:ok, _} =
        Geofences.upsert_subscription(%{
          "user_id" => subscriber.id,
          "geofence_id" => geofence.id,
          "throttle_seconds" => 0
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      # No notification because visibility is revoked
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
  end

  describe "geofence_created notification" do
    test "sends FCM notification for geofence_created" do
      creator = create_user(%{"display_name" => "Creator"})
      recipient = create_user(%{"display_name" => "Recipient"})
      group = create_group(creator)

      {:ok, invite} = Groups.get_or_create_invite(group.id, creator.id)
      {:ok, _} = Groups.join_by_invite_code(recipient.id, invite.code)

      geofence = create_geofence(group, creator)

      # Register a device token for the recipient
      {:ok, _} =
        Fence.Accounts.register_device_token(recipient.id, "fake-fcm-token-123", "ios")

      # The worker should complete without error
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "type" => "geofence_created",
                 "geofence_id" => geofence.id,
                 "group_id" => group.id,
                 "creator_id" => creator.id,
                 "recipient_id" => recipient.id
               })
    end

    test "handles missing entities gracefully" do
      creator = create_user(%{"display_name" => "Creator"})

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "type" => "geofence_created",
                 "geofence_id" => Ecto.UUID.generate(),
                 "group_id" => Ecto.UUID.generate(),
                 "creator_id" => creator.id,
                 "recipient_id" => Ecto.UUID.generate()
               })
    end
  end

  describe "home geofence filtering" do
    test "suppresses entry notification at triggering user's home by default" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      # Triggering user claims geofence as home
      claim_home(triggering_user, group, geofence)

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "suppresses exit notification at triggering user's home by default" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      claim_home(triggering_user, group, geofence)

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "exited"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "allows non-home geofence notifications through" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      # No home claimed — geofence is not a home geofence
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end

    test "household exception allows notification when notify_household is on" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      # Both users share the same home geofence
      claim_home(triggering_user, group, geofence)
      claim_home(subscriber, group, geofence)

      # notify_household defaults to true, so notification should go through
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end

    test "household exception blocked when notify_household is off" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      claim_home(triggering_user, group, geofence)
      claim_home(subscriber, group, geofence)

      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, group.id, %{
          "notify_household" => false
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert is_nil(Notifications.last_notification_time(subscriber.id, geofence.id))
    end

    test "home activity exception allows entry notification" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      claim_home(triggering_user, group, geofence)

      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, group.id, %{
          "notify_home_activity" => true
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end

    test "home activity exception allows exit notification" do
      {triggering_user, subscriber, geofence, group} = setup_geofence_with_subscriber()

      claim_home(triggering_user, group, geofence)

      {:ok, _} =
        Groups.update_notification_preferences(subscriber.id, group.id, %{
          "notify_home_activity" => true
        })

      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "exited"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end

    test "passes through when triggering user has no home claimed" do
      {triggering_user, subscriber, geofence, _group} = setup_geofence_with_subscriber()

      # Triggering user has no home_geofence_id set
      assert :ok =
               perform_job(PushNotificationWorker, %{
                 "user_id" => triggering_user.id,
                 "geofence_id" => geofence.id,
                 "event" => "entered"
               })

      assert Notifications.last_notification_time(subscriber.id, geofence.id)
    end
  end
end
