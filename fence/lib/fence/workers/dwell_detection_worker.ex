defmodule Fence.Workers.DwellDetectionWorker do
  use Oban.Worker, queue: :geofence_checks, max_attempts: 3

  require Logger
  import Ecto.Query

  alias Fence.Locations.{ActiveDwell, DeviceLocation, DwellSession}
  alias Fence.Repo
  alias Fence.Workers.DwellCategorizationWorker

  @cluster_radius_m 100
  @dwell_threshold_seconds 300

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "location_id" => location_id}}) do
    location = Repo.get(DeviceLocation, location_id)

    if location do
      {lat, lng} = extract_coords(location)
      if lat && lng, do: process_dwell(user_id, lat, lng)
    end

    :ok
  end

  defp extract_coords(%DeviceLocation{point: %Geo.Point{coordinates: {lng, lat}}}), do: {lat, lng}
  defp extract_coords(_), do: {nil, nil}

  defp process_dwell(user_id, lat, lng) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case get_active_dwell(user_id) do
      nil ->
        create_active_dwell(user_id, lat, lng, now)

      %ActiveDwell{} = dwell ->
        distance = haversine(dwell.center_lat, dwell.center_lng, lat, lng)

        if distance < @cluster_radius_m do
          update_cluster(dwell, now)
        else
          handle_moved_away(dwell, now)
          create_active_dwell(user_id, lat, lng, now)
        end
    end
  end

  defp get_active_dwell(user_id) do
    from(d in ActiveDwell, where: d.user_id == ^user_id)
    |> Repo.one()
  end

  defp create_active_dwell(user_id, lat, lng, now) do
    %ActiveDwell{}
    |> ActiveDwell.changeset(%{
      user_id: user_id,
      center_lat: lat,
      center_lng: lng,
      started_at: now,
      last_seen_at: now,
      point_count: 1,
      confirmed: false
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  defp update_cluster(%ActiveDwell{} = dwell, now) do
    elapsed = DateTime.diff(now, dwell.started_at, :second)
    new_count = dwell.point_count + 1

    changeset =
      ActiveDwell.changeset(dwell, %{
        last_seen_at: now,
        point_count: new_count
      })

    if elapsed >= @dwell_threshold_seconds and not dwell.confirmed do
      changeset
      |> Ecto.Changeset.put_change(:confirmed, true)
      |> Repo.update()

      create_dwell_session(dwell, now, new_count)
    else
      Repo.update(changeset)
    end
  end

  defp handle_moved_away(%ActiveDwell{} = dwell, now) do
    if dwell.confirmed do
      # End the dwell session
      from(ds in DwellSession,
        where:
          ds.user_id == ^dwell.user_id and
            ds.center_lat == ^dwell.center_lat and
            ds.center_lng == ^dwell.center_lng and
            is_nil(ds.ended_at),
        order_by: [desc: ds.started_at],
        limit: 1
      )
      |> Repo.one()
      |> case do
        nil -> :ok
        session ->
          duration = DateTime.diff(now, session.started_at, :second)

          session
          |> DwellSession.changeset(%{ended_at: now, duration_seconds: duration})
          |> Repo.update()
      end
    end

    # Delete active dwell
    Repo.delete(dwell)
  end

  defp create_dwell_session(%ActiveDwell{} = dwell, now, point_count) do
    duration = DateTime.diff(now, dwell.started_at, :second)

    case %DwellSession{}
         |> DwellSession.changeset(%{
           user_id: dwell.user_id,
           started_at: dwell.started_at,
           center_lat: dwell.center_lat,
           center_lng: dwell.center_lng,
           point_count: point_count,
           duration_seconds: duration,
           geocoding_status: "pending"
         })
         |> Repo.insert() do
      {:ok, session} ->
        %{dwell_session_id: session.id}
        |> DwellCategorizationWorker.new()
        |> Oban.insert()

        Logger.info(
          "[DwellDetection] Created dwell session #{session.id} for user #{dwell.user_id} " <>
            "at (#{dwell.center_lat}, #{dwell.center_lng})"
        )

      {:error, reason} ->
        Logger.warning("[DwellDetection] Failed to create dwell session: #{inspect(reason)}")
    end
  end

  @doc """
  Compute haversine distance in meters between two lat/lng points.
  """
  def haversine(lat1, lng1, lat2, lng2) do
    r = 6_371_000

    dlat = deg_to_rad(lat2 - lat1)
    dlng = deg_to_rad(lng2 - lng1)

    a =
      :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(deg_to_rad(lat1)) * :math.cos(deg_to_rad(lat2)) *
          :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    r * c
  end

  defp deg_to_rad(deg), do: deg * :math.pi() / 180
end
