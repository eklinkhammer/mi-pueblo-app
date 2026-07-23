defmodule Fence.Metrics do
  @moduledoc """
  App-level metrics: user counts and sync staleness percentiles.
  """

  import Ecto.Query
  alias Fence.Repo

  @doc "Returns total number of registered users."
  def total_user_count do
    Repo.aggregate(Fence.Accounts.User, :count)
  end

  @doc """
  Computes sync staleness percentiles across all users.
  Returns %{p50: seconds, p90: seconds} where seconds is how long
  since each user's most recent location report.
  """
  def sync_staleness_percentiles do
    now = DateTime.utc_now()

    staleness_values =
      from(l in Fence.Locations.DeviceLocation,
        distinct: l.user_id,
        order_by: [asc: l.user_id, desc: l.inserted_at],
        select: l.inserted_at
      )
      |> Repo.all()
      |> Enum.map(fn inserted_at -> DateTime.diff(now, inserted_at, :second) end)
      |> Enum.sort()

    case staleness_values do
      [] ->
        %{p50: 0, p90: 0}

      sorted ->
        len = length(sorted)

        %{
          p50: percentile_at(sorted, len, 0.50),
          p90: percentile_at(sorted, len, 0.90)
        }
    end
  end

  @doc "Count of users with a location report in the last 7 days."
  def tracked_user_count do
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    from(l in Fence.Locations.DeviceLocation,
      where: l.inserted_at >= ^seven_days_ago,
      select: count(l.user_id, :distinct)
    )
    |> Repo.one()
  end

  @doc "Count of users with a location report in the last 1 hour."
  def active_user_count do
    one_hour_ago = DateTime.add(DateTime.utc_now(), -1, :hour)

    from(l in Fence.Locations.DeviceLocation,
      where: l.inserted_at >= ^one_hour_ago,
      select: count(l.user_id, :distinct)
    )
    |> Repo.one()
  end

  @doc "Notification stats from push_logs: sent/errors counts for today and last hour."
  def notification_stats do
    now = DateTime.utc_now()
    one_hour_ago = DateTime.add(now, -1, :hour)
    start_of_day = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

    from(p in Fence.Notifications.PushLog,
      where: p.inserted_at >= ^start_of_day,
      select: %{
        sent_today:
          count(fragment("CASE WHEN ? = 'sent' THEN 1 END", p.status)),
        sent_hour:
          count(fragment("CASE WHEN ? = 'sent' AND ? >= ? THEN 1 END", p.status, p.inserted_at, ^one_hour_ago)),
        errors_today:
          count(fragment("CASE WHEN ? = 'failed' THEN 1 END", p.status)),
        errors_hour:
          count(fragment("CASE WHEN ? = 'failed' AND ? >= ? THEN 1 END", p.status, p.inserted_at, ^one_hour_ago))
      }
    )
    |> Repo.one()
    |> case do
      nil -> %{sent_today: 0, sent_hour: 0, errors_today: 0, errors_hour: 0}
      stats -> stats
    end
  end

  @doc "Total number of groups."
  def group_count do
    Repo.aggregate(Fence.Groups.Group, :count)
  end

  @doc "Count of geofences where expires_at is null or in the future."
  def active_geofence_count do
    now = DateTime.utc_now()

    from(g in Fence.Geofences.Geofence,
      where: is_nil(g.expires_at) or g.expires_at > ^now
    )
    |> Repo.aggregate(:count)
  end

  @doc "Count of geofence events recorded today."
  def geofence_events_today do
    start_of_day = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

    from(e in Fence.Locations.GeofenceEvent,
      where: e.inserted_at >= ^start_of_day
    )
    |> Repo.aggregate(:count)
  end

  defp percentile_at(sorted, len, p) do
    index = max(0, round(p * len) - 1)
    Enum.at(sorted, index, 0)
  end
end
