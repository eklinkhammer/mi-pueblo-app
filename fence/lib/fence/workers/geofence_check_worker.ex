defmodule Fence.Workers.GeofenceCheckWorker do
  use Oban.Worker,
    queue: :geofence_checks,
    max_attempts: 3

  require Logger

  import Ecto.Query

  alias Fence.Locations
  alias Fence.Locations.{DeviceLocation, PendingGeofenceTransition}
  alias Fence.Repo
  alias Fence.Workers.{DwellTimeWorker, PushNotificationWorker}

  @dialyzer {:nowarn_function, perform: 1}
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "location_id" => location_id} = args}) do
    source = Map.get(args, "source", "foreground")
    location = Repo.get(DeviceLocation, location_id)
    accuracy = (location && location.accuracy) || 10.0

    # Get current geofence state
    previous_ids = Locations.get_user_geofence_ids(user_id)

    # Apply EMA smoothing and find containing geofences using smoothed coords
    current_ids = find_geofences_with_smoothing(user_id, location_id, location)

    # Filter out geofences where accuracy is too poor relative to radius
    {current_ids, previous_ids} =
      filter_by_accuracy(user_id, current_ids, previous_ids, accuracy)

    # Compute entries and exits
    entered_ids = MapSet.difference(current_ids, previous_ids)
    exited_ids = MapSet.difference(previous_ids, current_ids)

    Logger.info(
      "[GeofenceCheck] user=#{user_id} location=#{location_id} source=#{source} " <>
        "previous=#{MapSet.size(previous_ids)} current=#{MapSet.size(current_ids)} " <>
        "entered=#{MapSet.size(entered_ids)} exited=#{MapSet.size(exited_ids)}"
    )

    if MapSet.size(entered_ids) > 0 do
      Logger.info("[GeofenceCheck] entered_ids=#{inspect(MapSet.to_list(entered_ids))}")
    end

    if MapSet.size(exited_ids) > 0 do
      Logger.info("[GeofenceCheck] exited_ids=#{inspect(MapSet.to_list(exited_ids))}")
    end

    # Route through dwell time system or apply directly
    dwell_config = Application.get_env(:fence, :geofence_dwell, [])
    entry_seconds = Keyword.get(dwell_config, :entry_seconds, 30)
    exit_seconds = Keyword.get(dwell_config, :exit_seconds, 60)

    if entry_seconds == 0 and exit_seconds == 0 do
      # No dwell time — apply immediately (test mode / backwards compatible)
      apply_immediate(user_id, entered_ids, exited_ids)
    else
      # Use dwell time system
      apply_with_dwell(user_id, entered_ids, exited_ids, entry_seconds, exit_seconds, current_ids)
    end

    # Broadcast location to group channels for all sources (foreground and background)
    if location do
      Locations.broadcast_location_update_from_record(user_id, location)
    end

    :ok
  end

  defp apply_immediate(user_id, entered_ids, exited_ids) do
    Locations.update_geofence_state(user_id, entered_ids, exited_ids)

    for geofence_id <- entered_ids do
      %{user_id: user_id, geofence_id: geofence_id, event: "entered"}
      |> PushNotificationWorker.new()
      |> Oban.insert()
    end

    for geofence_id <- exited_ids do
      %{user_id: user_id, geofence_id: geofence_id, event: "exited"}
      |> PushNotificationWorker.new()
      |> Oban.insert()
    end
  end

  defp apply_with_dwell(
         user_id,
         entered_ids,
         exited_ids,
         entry_seconds,
         exit_seconds,
         current_ids
       ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    for geofence_id <- entered_ids do
      upsert_pending(user_id, geofence_id, "entered", now, entry_seconds)
    end

    for geofence_id <- exited_ids do
      upsert_pending(user_id, geofence_id, "exited", now, exit_seconds)
    end

    # Cancel pending "entered" for geofences user is NOT currently inside
    # (covers rapid in/out where user left before dwell expired)
    cancel_contradicted_by_state(user_id, current_ids, "entered")
    # Cancel pending "exited" for geofences user IS currently inside
    cancel_confirmed_inside(user_id, current_ids, "exited")
  end

  defp upsert_pending(user_id, geofence_id, event, now, dwell_seconds) do
    existing =
      Repo.one(
        from(p in PendingGeofenceTransition,
          where: p.user_id == ^user_id and p.geofence_id == ^geofence_id
        )
      )

    case existing do
      nil ->
        # New pending transition
        %PendingGeofenceTransition{}
        |> PendingGeofenceTransition.changeset(%{
          user_id: user_id,
          geofence_id: geofence_id,
          event: event,
          first_seen_at: now,
          last_confirmed_at: now,
          confirmation_count: 1
        })
        |> Repo.insert()

        # Schedule dwell time check
        %{user_id: user_id, geofence_id: geofence_id}
        |> DwellTimeWorker.new(schedule_in: dwell_seconds)
        |> Oban.insert()

      %PendingGeofenceTransition{event: ^event} = pending ->
        # Same direction — confirm
        pending
        |> PendingGeofenceTransition.changeset(%{
          last_confirmed_at: now,
          confirmation_count: pending.confirmation_count + 1
        })
        |> Repo.update()

      %PendingGeofenceTransition{} = pending ->
        # Opposite direction — cancel the pending transition
        Repo.delete(pending)
    end
  end

  # Cancel pending "entered" transitions for geofences the user is NOT currently inside
  defp cancel_contradicted_by_state(user_id, current_ids, "entered") do
    current_list = MapSet.to_list(current_ids)

    query =
      if current_list == [] do
        from(p in PendingGeofenceTransition,
          where: p.user_id == ^user_id and p.event == "entered"
        )
      else
        from(p in PendingGeofenceTransition,
          where:
            p.user_id == ^user_id and p.event == "entered" and
              p.geofence_id not in ^current_list
        )
      end

    Repo.delete_all(query)
  end

  # Cancel pending "exited" transitions for geofences the user IS currently inside
  defp cancel_confirmed_inside(user_id, current_ids, "exited") do
    current_list = MapSet.to_list(current_ids)

    if current_list == [] do
      :ok
    else
      from(p in PendingGeofenceTransition,
        where:
          p.user_id == ^user_id and p.event == "exited" and
            p.geofence_id in ^current_list
      )
      |> Repo.delete_all()
    end
  end

  # Accuracy-based filtering: skip geofences where GPS accuracy > geofence radius
  defp filter_by_accuracy(_user_id, current_ids, previous_ids, accuracy)
       when accuracy <= 50.0 do
    # Good accuracy — no filtering needed
    {current_ids, previous_ids}
  end

  defp filter_by_accuracy(user_id, current_ids, previous_ids, accuracy) do
    # Get radii for all geofences the user is a member of
    geofence_radii = Locations.get_user_geofence_radii(user_id)

    # Only consider geofences where accuracy <= radius
    all_ids = MapSet.union(current_ids, previous_ids)

    skip_ids =
      all_ids
      |> Enum.filter(fn gid ->
        case Map.get(geofence_radii, gid) do
          nil -> false
          radius -> accuracy > radius
        end
      end)
      |> MapSet.new()

    if MapSet.size(skip_ids) > 0 do
      Logger.info(
        "[GeofenceCheck] Skipping #{MapSet.size(skip_ids)} geofences due to poor accuracy (#{accuracy}m)"
      )
    end

    {MapSet.difference(current_ids, skip_ids), MapSet.difference(previous_ids, skip_ids)}
  end

  defp find_geofences_with_smoothing(user_id, location_id, location) do
    case location do
      %DeviceLocation{point: %Geo.Point{coordinates: {_lng, _lat}}, accuracy: accuracy}
      when is_nil(accuracy) or accuracy <= 20.0 ->
        # High accuracy — use raw location
        Locations.find_containing_geofences(user_id, location_id)

      %DeviceLocation{point: %Geo.Point{coordinates: {lng, lat}}, accuracy: accuracy} ->
        {smoothed_lat, smoothed_lng} = apply_ema(user_id, lat, lng, accuracy)
        Locations.find_containing_geofences_by_coords(user_id, smoothed_lat, smoothed_lng)

      _ ->
        Locations.find_containing_geofences(user_id, location_id)
    end
  end

  @doc """
  Apply Exponential Moving Average to smooth GPS coordinates.
  Alpha is scaled by accuracy: high accuracy -> trust new reading,
  low accuracy -> mostly keep previous smoothed position.
  """
  def apply_ema(user_id, lat, lng, accuracy) do
    alpha = min(1.0, 20.0 / max(accuracy, 1.0))

    case ema_lookup(user_id) do
      nil ->
        # First reading — use raw value
        ema_store(user_id, lat, lng)
        {lat, lng}

      {prev_lat, prev_lng} ->
        smoothed_lat = prev_lat + alpha * (lat - prev_lat)
        smoothed_lng = prev_lng + alpha * (lng - prev_lng)
        ema_store(user_id, smoothed_lat, smoothed_lng)
        {smoothed_lat, smoothed_lng}
    end
  end

  defp ema_lookup(user_id) do
    case :ets.lookup(:geofence_ema, user_id) do
      [{^user_id, lat, lng}] -> {lat, lng}
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp ema_store(user_id, lat, lng) do
    :ets.insert(:geofence_ema, {user_id, lat, lng})
  rescue
    ArgumentError -> :ok
  end
end
