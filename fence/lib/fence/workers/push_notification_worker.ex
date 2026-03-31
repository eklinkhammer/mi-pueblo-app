defmodule Fence.Workers.PushNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3
  use Gettext, backend: FenceWeb.Gettext

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
    if should_skip?(subscription, triggering_user, event) do
      :skip
    else
      send_or_throttle(subscription, triggering_user, geofence, event)
    end
  end

  defp should_skip?(subscription, triggering_user, event) do
    subscription.user_id == triggering_user.id or
      (event == "entered" and not subscription.notify_on_entry) or
      (event == "exited" and not subscription.notify_on_exit) or
      triggering_user.id in (subscription.blacklisted_user_ids || [])
  end

  defp send_or_throttle(subscription, triggering_user, geofence, event) do
    if Notifications.should_throttle?(
         subscription.user_id,
         geofence.id,
         subscription.throttle_seconds
       ) do
      Notifications.log_push(%{
        recipient_id: subscription.user_id,
        triggering_user_id: triggering_user.id,
        geofence_id: geofence.id,
        event: event,
        status: "throttled"
      })
    else
      send_push(subscription.user_id, triggering_user, geofence, event)
    end
  end

  defp send_push(recipient_id, triggering_user, geofence, event) do
    tokens = Accounts.get_device_tokens(recipient_id)
    recipient = Accounts.get_user(recipient_id)
    locale = (recipient && recipient.locale) || "en"

    {title, body} =
      Gettext.with_locale(FenceWeb.Gettext, locale, fn ->
        t = localized_title(triggering_user.display_name, geofence.name, event)
        b = localized_body(triggering_user.display_name, geofence.name, event)
        {t, b}
      end)

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

  defp localized_title(user_name, geofence_name, "entered") do
    gettext("%{user_name} entered %{geofence_name}",
      user_name: user_name,
      geofence_name: geofence_name
    )
  end

  defp localized_title(user_name, geofence_name, "exited") do
    gettext("%{user_name} exited %{geofence_name}",
      user_name: user_name,
      geofence_name: geofence_name
    )
  end

  defp localized_body(user_name, geofence_name, "entered") do
    gettext("%{user_name} has arrived at %{geofence_name}",
      user_name: user_name,
      geofence_name: geofence_name
    )
  end

  defp localized_body(user_name, geofence_name, "exited") do
    gettext("%{user_name} has left %{geofence_name}",
      user_name: user_name,
      geofence_name: geofence_name
    )
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
