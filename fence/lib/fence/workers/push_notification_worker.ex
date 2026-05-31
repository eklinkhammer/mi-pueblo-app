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
        args: %{
          "type" => "geofence_created",
          "geofence_id" => geofence_id,
          "group_id" => group_id,
          "creator_id" => creator_id,
          "recipient_id" => recipient_id
        }
      }) do
    geofence = Geofences.get_geofence(geofence_id)
    creator = Accounts.get_user(creator_id)
    group = Groups.get_group(group_id)
    recipient = Accounts.get_user(recipient_id)

    if geofence && creator && group && recipient do
      tokens = Accounts.get_device_tokens(recipient_id)
      locale = (recipient && recipient.locale) || "en"

      {title, body} =
        Gettext.with_locale(FenceWeb.Gettext, locale, fn ->
          t =
            gettext("New geofence in %{group_name}",
              group_name: group.name
            )

          b =
            gettext("%{creator_name} created %{geofence_name}",
              creator_name: creator.display_name,
              geofence_name: geofence.name
            )

          {t, b}
        end)

      for token <- tokens do
        send_fcm(token.token, title, body, %{
          type: "geofence_created",
          geofence_id: geofence.id,
          group_id: group.id
        })
      end
    end

    :ok
  end

  def perform(%Oban.Job{
        args: %{"user_id" => triggering_user_id, "geofence_id" => geofence_id, "event" => event}
      }) do
    Logger.info(
      "[PushWorker] Processing user=#{triggering_user_id} geofence=#{geofence_id} event=#{event}"
    )

    geofence = Geofences.get_geofence(geofence_id)

    if geofence do
      subscribers = Geofences.list_geofence_subscribers(geofence_id)
      triggering_user = Accounts.get_user(triggering_user_id)
      subscriber_ids = Enum.map(subscribers, & &1.user_id)

      Logger.info(
        "[PushWorker] geofence=#{geofence.name} subscriber_count=#{length(subscriber_ids)}"
      )

      # Batch-load preference data (no N+1)
      prefs_context = load_notification_prefs(subscriber_ids, triggering_user_id, geofence)

      for sub <- subscribers do
        send_if_eligible(sub, triggering_user, geofence, event, prefs_context)
      end

      # Look up triggering user's sharing mode and visibility
      membership =
        Fence.Repo.get_by(Fence.Groups.Membership,
          user_id: triggering_user_id,
          group_id: geofence.group_id
        )

      sharing_mode = if membership, do: membership.sharing_mode, else: "live"

      # Broadcast geofence event to group channel
      broadcast_geofence_event(
        triggering_user,
        geofence,
        event,
        sharing_mode,
        prefs_context.visible_set
      )
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
    case skip_reason(subscription, triggering_user, event, prefs_context) do
      nil ->
        send_or_throttle(subscription, triggering_user, geofence, event)

      reason ->
        Logger.info(
          "[PushFilter] Skipping subscriber=#{subscription.user_id} " <>
            "geofence=#{geofence.id} event=#{event} reason=#{reason}"
        )

        :skip
    end
  end

  defp skip_reason(subscription, triggering_user, event, prefs_context) do
    subscriber_id = subscription.user_id
    %{visible_set: visible_set} = prefs_context

    cond do
      not MapSet.member?(visible_set, subscriber_id) ->
        :not_visible

      true ->
        skip_reason_visible(subscription, triggering_user, event, prefs_context)
    end
  end

  defp skip_reason_visible(subscription, triggering_user, event, prefs_context) do
    subscriber_id = subscription.user_id

    %{
      memberships_by_user: memberships_by_user,
      is_home_geofence: is_home_geofence,
      triggering_home_id: triggering_home_id
    } = prefs_context

    subscriber_membership = Map.get(memberships_by_user, subscriber_id)

    if is_home_geofence do
      is_household =
        triggering_home_id != nil and
          subscriber_membership != nil and
          subscriber_membership.home_geofence_id == triggering_home_id

      cond do
        is_household and subscriber_membership != nil and subscriber_membership.notify_household ->
          original_skip_reason(subscription, triggering_user, event)

        subscriber_membership != nil and subscriber_membership.notify_home_activity ->
          original_skip_reason(subscription, triggering_user, event)

        true ->
          :home_geofence_filtered
      end
    else
      original_skip_reason(subscription, triggering_user, event)
    end
  end

  defp original_skip_reason(subscription, triggering_user, event) do
    cond do
      subscription.user_id == triggering_user.id -> :self_skip
      event == "entered" and not subscription.notify_on_entry -> :entry_pref_off
      event == "exited" and not subscription.notify_on_exit -> :exit_pref_off
      triggering_user.id in (subscription.blacklisted_user_ids || []) -> :blacklisted
      true -> nil
    end
  end

  defp send_or_throttle(subscription, triggering_user, geofence, event) do
    if Notifications.should_throttle?(
         subscription.user_id,
         geofence.id,
         subscription.throttle_seconds
       ) do
      Logger.info(
        "[PushFilter] Throttled subscriber=#{subscription.user_id} geofence=#{geofence.id}"
      )

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

    Logger.info(
      "[Push] Sending to recipient=#{recipient_id} geofence=#{geofence.id} " <>
        "event=#{event} token_count=#{length(tokens)}"
    )

    {title, body} =
      Gettext.with_locale(FenceWeb.Gettext, locale, fn ->
        t = localized_title(triggering_user.display_name, geofence.name, event)
        b = localized_body(triggering_user.display_name, geofence.name, event)
        {t, b}
      end)

    results =
      for token <- tokens do
        send_fcm(token.token, title, body, %{
          geofence_id: geofence.id,
          group_id: geofence.group_id,
          user_id: triggering_user.id,
          event: event
        })
      end

    status = if Enum.all?(results, &(&1 == :ok)), do: "sent", else: "fcm_error"

    Notifications.log_push(%{
      recipient_id: recipient_id,
      triggering_user_id: triggering_user.id,
      geofence_id: geofence.id,
      event: event,
      status: status
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

      result = Fence.FCM.push(notification)

      case result do
        %{response: :success} ->
          Logger.info("[FCM] Push sent to #{String.slice(device_token, 0, 10)}...")
          :ok

        error ->
          Logger.error(
            "[FCM] Push FAILED to #{String.slice(device_token, 0, 10)}... " <>
              "error_type=#{error.__struct__} response=#{inspect(error)}"
          )

          :error
      end
    else
      Logger.warning(
        "[FCM] Not configured — would push to #{String.slice(device_token, 0, 10)}...: #{title}"
      )

      :error
    end
  end

  defp broadcast_geofence_event(triggering_user, geofence, event, sharing_mode, visible_set) do
    {geofence_longitude, geofence_latitude} =
      case geofence.center do
        %Geo.Point{coordinates: coords} -> coords
        _ -> {nil, nil}
      end

    payload = %{
      user_id: triggering_user.id,
      display_name: triggering_user.display_name,
      avatar_url: triggering_user.avatar_url,
      geofence_id: geofence.id,
      geofence_name: geofence.name,
      geofence_latitude: geofence_latitude,
      geofence_longitude: geofence_longitude,
      event: event,
      sharing_mode: sharing_mode,
      visible_to: MapSet.to_list(visible_set)
    }

    FenceWeb.Endpoint.broadcast(
      "group:#{geofence.group_id}",
      "geofence:#{event}",
      payload
    )
  end
end
