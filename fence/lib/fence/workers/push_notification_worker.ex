defmodule Fence.Workers.PushNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3
  use Gettext, backend: FenceWeb.Gettext

  alias Fence.{Accounts, Geofences, Groups, Notifications}
  alias Pigeon.FCM.Notification, as: FCMNotification

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"type" => "member_joined", "group_id" => group_id, "user_id" => new_user_id}
      }) do
    new_user = Accounts.get_user(new_user_id)
    group = Groups.get_group(group_id)

    if new_user && group do
      members = Groups.list_members(group_id)

      for member <- members, member.user_id != new_user_id do
        notify_member_joined(member, new_user, group)
      end
    end

    :ok
  end

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

  defp load_notification_prefs(_subscriber_ids, triggering_user_id, geofence) do
    # 1. Memberships for all subscribers in this group → silence flags + home_geofence_id
    memberships = Groups.list_members(geofence.group_id)
    memberships_by_user = Map.new(memberships, fn m -> {m.user_id, m} end)

    # 2. Is this a home notification? (triggering user's home_geofence_id == geofence.id)
    triggering_membership = Map.get(memberships_by_user, triggering_user_id)

    is_home_geofence =
      triggering_membership != nil and
        triggering_membership.home_geofence_id != nil and
        triggering_membership.home_geofence_id == geofence.id

    # 3. Triggering user's home_geofence_id (for household detection)
    triggering_home_id = triggering_membership && triggering_membership.home_geofence_id

    # 4. Visibility: which subscribers can see the triggering user
    visible_set = Groups.visible_user_ids(triggering_user_id, geofence.group_id)

    %{
      memberships_by_user: memberships_by_user,
      is_home_geofence: is_home_geofence,
      triggering_home_id: triggering_home_id,
      visible_set: visible_set
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

    %{visible_set: visible_set} = prefs_context

    not MapSet.member?(visible_set, subscriber_id) or
      should_skip_visible?(subscription, triggering_user, event, prefs_context)
  end

  defp should_skip_visible?(subscription, triggering_user, event, prefs_context) do
    subscriber_id = subscription.user_id

    %{
      memberships_by_user: memberships_by_user,
      is_home_geofence: is_home_geofence,
      triggering_home_id: triggering_home_id
    } = prefs_context

    subscriber_membership = Map.get(memberships_by_user, subscriber_id)

    is_household =
      triggering_home_id != nil and
        subscriber_membership != nil and
        subscriber_membership.home_geofence_id == triggering_home_id

    cond do
      is_household and subscriber_membership != nil and subscriber_membership.notify_household ->
        original_skip?(subscription, triggering_user, event)

      group_or_home_silenced?(subscriber_membership, is_home_geofence) ->
        true

      true ->
        original_skip?(subscription, triggering_user, event)
    end
  end

  defp group_or_home_silenced?(nil, _is_home), do: false

  defp group_or_home_silenced?(membership, is_home) do
    membership.silence_all_notifications or
      (is_home and membership.silence_home_notifications)
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

  defp notify_member_joined(member, new_user, group) do
    tokens = Accounts.get_device_tokens(member.user_id)
    recipient = Accounts.get_user(member.user_id)
    locale = (recipient && recipient.locale) || "en"

    {title, body} =
      Gettext.with_locale(FenceWeb.Gettext, locale, fn ->
        t =
          gettext("%{user_name} joined %{group_name}",
            user_name: new_user.display_name,
            group_name: group.name
          )

        b = gettext("Grant visibility to see each other's location")
        {t, b}
      end)

    for token <- tokens do
      send_fcm(token.token, title, body, %{
        type: "member_joined",
        group_id: group.id,
        user_id: new_user.id
      })
    end
  end

  defp send_fcm(device_token, title, body, data) do
    if Application.get_env(:fence, :fcm_credentials) do
      notification =
        FCMNotification.new(
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
