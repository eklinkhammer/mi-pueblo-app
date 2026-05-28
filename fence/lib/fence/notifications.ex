defmodule Fence.Notifications do
  import Ecto.Query
  alias Fence.Accounts.User
  alias Fence.Notifications.PushLog
  alias Fence.Repo

  def log_push(attrs) do
    %PushLog{}
    |> PushLog.changeset(attrs)
    |> Repo.insert()
  end

  def last_notification_time(recipient_id, geofence_id) do
    from(p in PushLog,
      where:
        p.recipient_id == ^recipient_id and
          p.geofence_id == ^geofence_id and
          p.status == "sent",
      order_by: [desc: p.inserted_at],
      limit: 1,
      select: p.inserted_at
    )
    |> Repo.one()
  end

  def list_geofence_activity(geofence_id, visible_user_ids, limit \\ 10) do
    from(p in PushLog,
      where:
        p.geofence_id == ^geofence_id and p.status == "sent" and
          p.triggering_user_id in ^visible_user_ids,
      left_join: u in User,
      on: u.id == p.triggering_user_id,
      distinct: [p.triggering_user_id, p.event, p.inserted_at],
      order_by: [asc: p.triggering_user_id, asc: p.event, desc: p.inserted_at],
      limit: ^limit,
      select: %{
        event: p.event,
        user_name: fragment("COALESCE(?, 'Deleted user')", u.display_name),
        inserted_at: p.inserted_at
      }
    )
    |> Repo.all()
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  # Throttling

  def should_throttle?(recipient_id, geofence_id, throttle_seconds) do
    case last_notification_time(recipient_id, geofence_id) do
      nil ->
        false

      last_time ->
        cutoff = DateTime.add(last_time, throttle_seconds, :second)
        DateTime.compare(DateTime.utc_now(), cutoff) == :lt
    end
  end
end
