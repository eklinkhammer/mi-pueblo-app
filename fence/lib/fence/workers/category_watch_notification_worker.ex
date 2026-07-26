defmodule Fence.Workers.CategoryWatchNotificationWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3
  use Gettext, backend: FenceWeb.Gettext

  require Logger
  import Ecto.Query

  alias Fence.{Accounts, Groups}
  alias Fence.Locations.{CategoryWatch, DwellSession}
  alias Fence.Repo
  alias Pigeon.FCM.Notification, as: FCMNotification

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dwell_session_id" => session_id}}) do
    case Repo.get(DwellSession, session_id) do
      nil ->
        Logger.warning("[CategoryWatchNotify] Session #{session_id} not found")
        :ok

      %DwellSession{category: nil} ->
        :ok

      session ->
        notify_watchers(session)
    end
  end

  defp notify_watchers(%DwellSession{} = session) do
    watches = list_active_watches(session.user_id, session.category)
    triggering_user = Accounts.get_user(session.user_id)

    if triggering_user do
      for watch <- watches do
        process_watch(watch, triggering_user, session)
      end
    end

    :ok
  end

  defp list_active_watches(watched_user_id, category) do
    from(w in CategoryWatch,
      where:
        w.watched_user_id == ^watched_user_id and
          w.category == ^category and
          w.active == true
    )
    |> Repo.all()
  end

  defp process_watch(%CategoryWatch{} = watch, triggering_user, session) do
    # Verify visibility is still active
    visible_groups = Groups.visible_group_ids(watch.watcher_id, watch.watched_user_id)

    if Enum.empty?(visible_groups) do
      Logger.info(
        "[CategoryWatchNotify] Skipping watch #{watch.id}: no visibility between #{watch.watcher_id} and #{watch.watched_user_id}"
      )
    else
      if should_throttle?(watch) do
        Logger.info("[CategoryWatchNotify] Throttled watch #{watch.id}")
      else
        send_notification(watch, triggering_user, session)
      end
    end
  end

  defp should_throttle?(%CategoryWatch{} = watch) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-watch.throttle_seconds, :second)

    from(ds in DwellSession,
      where:
        ds.user_id == ^watch.watched_user_id and
          ds.category == ^watch.category and
          ds.started_at > ^cutoff and
          ds.geocoding_status == "categorized",
      select: count(ds.id)
    )
    |> Repo.one()
    |> Kernel.>(1)
  end

  defp send_notification(%CategoryWatch{} = watch, triggering_user, session) do
    tokens = Accounts.get_device_tokens(watch.watcher_id)
    recipient = Accounts.get_user(watch.watcher_id)
    locale = (recipient && recipient.locale) || "en"

    display_category = String.replace(session.category, "_", " ")

    {title, body} =
      Gettext.with_locale(FenceWeb.Gettext, locale, fn ->
        t =
          gettext("%{user_name} visited a %{category}",
            user_name: triggering_user.display_name,
            category: display_category
          )

        b =
          gettext("%{user_name} arrived at %{place_name} (%{category})",
            user_name: triggering_user.display_name,
            place_name: session.display_name || "Unknown",
            category: display_category
          )

        {t, b}
      end)

    Logger.info(
      "[CategoryWatchNotify] Sending to watcher=#{watch.watcher_id} " <>
        "about user=#{triggering_user.id} category=#{session.category}"
    )

    for token <- tokens do
      send_fcm(token.token, title, body, %{
        type: "category_watch",
        user_id: triggering_user.id,
        dwell_session_id: session.id,
        category: session.category,
        latitude: session.center_lat,
        longitude: session.center_lng
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
          Logger.info("[FCM] Category watch push sent to #{String.slice(device_token, 0, 10)}...")
          :ok

        error ->
          Logger.error("[FCM] Category watch push FAILED: #{inspect(error)}")
          :error
      end
    else
      Logger.warning(
        "[FCM] Not configured — would push category watch to #{String.slice(device_token, 0, 10)}...: #{title}"
      )

      :error
    end
  end
end
