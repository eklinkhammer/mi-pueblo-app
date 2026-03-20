defmodule Fence.Workers.PushNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias Fence.{Accounts, Geofences, Notifications}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => triggering_user_id, "geofence_id" => geofence_id, "event" => event}
      }) do
    geofence = Geofences.get_geofence(geofence_id)

    if geofence do
      subscribers = Geofences.list_geofence_subscribers(geofence_id)
      triggering_user = Accounts.get_user(triggering_user_id)

      for sub <- subscribers do
        send_if_eligible(sub, triggering_user, geofence, event)
      end

      # Broadcast geofence event to group channel
      broadcast_geofence_event(triggering_user, geofence, event)
    end

    :ok
  end

  defp send_if_eligible(subscription, triggering_user, geofence, event) do
    cond do
      # Don't notify the triggering user about themselves
      subscription.user_id == triggering_user.id ->
        :skip

      # Check event type preference
      event == "entered" and not subscription.notify_on_entry ->
        :skip

      event == "exited" and not subscription.notify_on_exit ->
        :skip

      # Check blacklist
      triggering_user.id in (subscription.blacklisted_user_ids || []) ->
        :skip

      # Check throttle
      Notifications.should_throttle?(
        subscription.user_id,
        geofence.id,
        subscription.throttle_seconds
      ) ->
        Notifications.log_push(%{
          recipient_id: subscription.user_id,
          triggering_user_id: triggering_user.id,
          geofence_id: geofence.id,
          event: event,
          status: "throttled"
        })

      true ->
        send_push(subscription.user_id, triggering_user, geofence, event)
    end
  end

  defp send_push(recipient_id, triggering_user, geofence, event) do
    tokens = Accounts.get_device_tokens(recipient_id)

    title = "#{triggering_user.display_name} #{event} #{geofence.name}"

    body =
      case event do
        "entered" -> "#{triggering_user.display_name} has arrived at #{geofence.name}"
        "exited" -> "#{triggering_user.display_name} has left #{geofence.name}"
      end

    for token <- tokens do
      send_fcm(token.token, title, body, %{
        geofence_id: geofence.id,
        user_id: triggering_user.id,
        event: event
      })
    end

    Notifications.log_push(%{
      recipient_id: recipient_id,
      triggering_user_id: triggering_user.id,
      geofence_id: geofence.id,
      event: event,
      status: "sent"
    })
  end

  defp send_fcm(device_token, title, body, data) do
    # FCM push via Pigeon - configure Pigeon.FCM in production
    # For now, log the notification
    Logger.info(
      "FCM push to #{String.slice(device_token, 0, 10)}...: #{title} - #{body} data=#{inspect(data)}"
    )

    # When Pigeon FCM is configured:
    # notification = Pigeon.FCM.Notification.new(device_token, %{
    #   "title" => title,
    #   "body" => body
    # }, data)
    # Pigeon.FCM.push(notification)
  end

  defp broadcast_geofence_event(triggering_user, geofence, event) do
    payload = %{
      user_id: triggering_user.id,
      display_name: triggering_user.display_name,
      geofence_id: geofence.id,
      geofence_name: geofence.name,
      event: event
    }

    FenceWeb.Endpoint.broadcast(
      "group:#{geofence.group_id}",
      "geofence:#{event}",
      payload
    )
  end
end
