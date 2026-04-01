defmodule Fence.Workers.PushNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3
  use Gettext, backend: FenceWeb.Gettext

  alias Fence.{Accounts, Geofences, Groups, Notifications}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"user_id" => triggering_user_id, "geofence_id" => geofence_id, "event" => event}
      }) do
    geofence = Geofences.get_geofence(geofence_id)

    if geofence do
      subscribers = Geofences.list_geofence_subscribers(geofence_id)
      triggering_user = Accounts.get_user(triggering_user_id)
      subscriber_ids = Enum.map(subscribers, & &1.user_id)

      # Batch-load preference data (no N+1)
      prefs_context = load_notification_prefs(subscriber_ids, triggering_user_id, geofence)

      for sub <- subscribers do
        send_if_eligible(sub, triggering_user, geofence, event, prefs_context)
      end

      # Broadcast geofence event to group channel
      broadcast_geofence_event(triggering_user, geofence, event)
    end

    :ok
  end

  defp load_notification_prefs(subscriber_ids, triggering_user_id, geofence) do
    # 1. Memberships for all subscribers in this group → silence flags + home_geofence_id
    memberships = Groups.list_members(geofence.group_id)
    memberships_by_user = Map.new(memberships, fn m -> {m.user_id, m} end)

    # 2. Per-member prefs where observer is a subscriber and subject is triggering user
    member_prefs =
      Notifications.get_member_notification_preferences_for_subject(
        subscriber_ids,
        triggering_user_id,
        geofence.group_id
      )

    prefs_by_observer = Map.new(member_prefs, fn p -> {p.observer_id, p} end)

    # 3. Is this a home notification? (triggering user's home_geofence_id == geofence.id)
    triggering_membership = Map.get(memberships_by_user, triggering_user_id)

    is_home_geofence =
      triggering_membership != nil and
        triggering_membership.home_geofence_id != nil and
        triggering_membership.home_geofence_id == geofence.id

    # 4. Triggering user's home_geofence_id (for household detection)
    triggering_home_id = triggering_membership && triggering_membership.home_geofence_id

    %{
      memberships_by_user: memberships_by_user,
      prefs_by_observer: prefs_by_observer,
      is_home_geofence: is_home_geofence,
      triggering_home_id: triggering_home_id
    }
  end

  defp send_if_eligible(subscription, triggering_user, geofence, event, prefs_context) do
    if should_skip?(subscription, triggering_user, event, prefs_context) do
      :skip
    else
      send_or_throttle(subscription, triggering_user, geofence, event)
    end
  end

  defp should_skip?(subscription, triggering_user, event, prefs_context) do
    subscriber_id = subscription.user_id
    %{
      memberships_by_user: memberships_by_user,
      prefs_by_observer: prefs_by_observer,
      is_home_geofence: is_home_geofence,
      triggering_home_id: triggering_home_id
    } = prefs_context

    subscriber_membership = Map.get(memberships_by_user, subscriber_id)
    member_pref = Map.get(prefs_by_observer, subscriber_id)

    # 1. Household override: if triggering user is a household member AND notify_household is on → SEND
    is_household =
      triggering_home_id != nil and
        subscriber_membership != nil and
        subscriber_membership.home_geofence_id == triggering_home_id

    if is_household and subscriber_membership != nil and subscriber_membership.notify_household do
      # Household override — only skip if original conditions match (self, entry/exit disabled, blacklisted)
      original_skip?(subscription, triggering_user, event)
    else
      # 2. Group silenced
      group_silenced =
        subscriber_membership != nil and subscriber_membership.silence_all_notifications

      # 3. Home silenced by group
      home_silenced =
        is_home_geofence and subscriber_membership != nil and
          subscriber_membership.silence_home_notifications

      # 4. User muted
      user_muted = member_pref != nil and not member_pref.notify

      # 5. User home muted
      user_home_muted = is_home_geofence and member_pref != nil and not member_pref.notify_home

      group_silenced or home_silenced or user_muted or user_home_muted or
        original_skip?(subscription, triggering_user, event)
    end
  end

  defp original_skip?(subscription, triggering_user, event) do
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
    if Application.get_env(:fence, :fcm_credentials) do
      notification =
        Pigeon.FCM.Notification.new(
          {:token, device_token},
          %{"title" => title, "body" => body},
          data
        )

      case Fence.FCM.push(notification) do
        %{response: :success} ->
          Logger.info("FCM push sent to #{String.slice(device_token, 0, 10)}...")

        error ->
          Logger.warning("FCM push failed: #{inspect(error)}")
      end
    else
      Logger.info(
        "FCM not configured — would push to #{String.slice(device_token, 0, 10)}...: #{title} - #{body}"
      )
    end
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
