defmodule Fence.Notifications do
  import Ecto.Query
  alias Fence.Repo
  alias Fence.Notifications.PushLog

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
