defmodule Fence.Notifications do
  import Ecto.Query
  alias Fence.Notifications.{MemberNotificationPreference, PushLog}
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

  # Member notification preferences

  def upsert_member_notification_preference(attrs) do
    %MemberNotificationPreference{}
    |> MemberNotificationPreference.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:notify, :notify_home, :updated_at]},
      conflict_target: [:observer_id, :subject_id, :group_id],
      returning: true
    )
  end

  def list_member_notification_preferences(observer_id, group_id) do
    from(p in MemberNotificationPreference,
      where: p.observer_id == ^observer_id and p.group_id == ^group_id
    )
    |> Repo.all()
  end

  def get_member_notification_preference(observer_id, subject_id, group_id) do
    Repo.get_by(MemberNotificationPreference,
      observer_id: observer_id,
      subject_id: subject_id,
      group_id: group_id
    )
  end

  def get_member_notification_preferences_for_subject(observer_ids, subject_id, group_id) do
    from(p in MemberNotificationPreference,
      where:
        p.observer_id in ^observer_ids and
          p.subject_id == ^subject_id and
          p.group_id == ^group_id
    )
    |> Repo.all()
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
