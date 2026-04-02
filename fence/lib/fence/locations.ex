defmodule Fence.Locations do
  import Ecto.Query
  alias Fence.{Accounts, Groups}
  alias Fence.Locations.{DeviceLocation, UserGeofenceState}
  alias Fence.Repo
  alias Fence.Workers.{GeofenceCheckWorker, PushNotificationWorker}

  def report_location(user_id, attrs) do
    location_attrs = Map.put(attrs, "user_id", user_id)

    result =
      %DeviceLocation{}
      |> DeviceLocation.changeset(location_attrs)
      |> Repo.insert()

    case result do
      {:ok, location} ->
        # Enqueue geofence check
        %{user_id: user_id, location_id: location.id, source: location.source}
        |> GeofenceCheckWorker.new()
        |> Oban.insert()

        {:ok, location}

      error ->
        error
    end
  end

  def get_last_location(user_id) do
    from(l in DeviceLocation,
      where: l.user_id == ^user_id,
      order_by: [desc: l.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_all_last_locations do
    from(l in DeviceLocation,
      join: u in Fence.Accounts.User,
      on: u.id == l.user_id,
      distinct: l.user_id,
      order_by: [asc: l.user_id, desc: l.inserted_at],
      select: %{
        user_id: l.user_id,
        display_name: u.display_name,
        point: l.point,
        accuracy: l.accuracy,
        speed: l.speed,
        battery_level: l.battery_level,
        updated_at: l.inserted_at
      }
    )
    |> Repo.all()
  end

  def get_group_last_locations(group_id, viewer_user_id) do
    visible_ids = Groups.visible_user_ids(viewer_user_id, group_id)
    allowed_ids = MapSet.put(visible_ids, viewer_user_id) |> MapSet.to_list()

    from(l in DeviceLocation,
      join: m in Fence.Groups.Membership,
      on: m.user_id == l.user_id and m.group_id == ^group_id,
      join: u in Fence.Accounts.User,
      on: u.id == l.user_id,
      where: l.user_id in ^allowed_ids,
      distinct: l.user_id,
      order_by: [asc: l.user_id, desc: l.inserted_at],
      select: %{
        user_id: l.user_id,
        display_name: u.display_name,
        point: l.point,
        accuracy: l.accuracy,
        speed: l.speed,
        battery_level: l.battery_level,
        updated_at: l.inserted_at
      }
    )
    |> Repo.all()
  end

  # Geofence state management

  def get_user_geofence_ids(user_id) do
    from(s in UserGeofenceState,
      where: s.user_id == ^user_id,
      select: s.geofence_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  # sobelow_skip ["SQL.Query"]
  def find_containing_geofences(user_id, location_id) do
    # Use PostGIS to find all active geofences containing this point
    now = DateTime.utc_now()

    query = """
    SELECT g.id
    FROM geofences g
    JOIN memberships m ON m.group_id = g.group_id AND m.user_id = $1
    JOIN device_locations dl ON dl.id = $2
    LEFT JOIN geofence_opt_outs oo ON oo.geofence_id = g.id AND oo.user_id = $1
    WHERE ST_Contains(g.boundary, dl.point)
      AND g.expires_at > $3
      AND oo.id IS NULL
    """

    case Repo.query(query, [Ecto.UUID.dump!(user_id), Ecto.UUID.dump!(location_id), now]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [id] -> Ecto.UUID.cast!(id) end)
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end

  def update_geofence_state(user_id, entered_ids, exited_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Insert new entries
    for geofence_id <- entered_ids do
      %UserGeofenceState{}
      |> UserGeofenceState.changeset(%{
        user_id: user_id,
        geofence_id: geofence_id,
        entered_at: now
      })
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :geofence_id])
    end

    # Remove exited
    if MapSet.size(exited_ids) > 0 do
      exited_list = MapSet.to_list(exited_ids)

      from(s in UserGeofenceState,
        where: s.user_id == ^user_id and s.geofence_id in ^exited_list
      )
      |> Repo.delete_all()
    end

    :ok
  end

  def broadcast_location_update(user_id, location_id) do
    location = Repo.get(DeviceLocation, location_id)

    if location do
      groups = Groups.list_user_groups(user_id)
      user = Accounts.get_user(user_id)

      {lng, lat} =
        case location.point do
          %Geo.Point{coordinates: coords} -> coords
          _ -> {nil, nil}
        end

      payload = %{
        user_id: user_id,
        display_name: user && user.display_name,
        latitude: lat,
        longitude: lng,
        accuracy: location.accuracy,
        speed: location.speed,
        battery_level: location.battery_level,
        updated_at: location.inserted_at
      }

      for group <- groups do
        FenceWeb.Endpoint.broadcast("group:#{group.id}", "location:updated", payload)
      end
    end
  end

  # sobelow_skip ["SQL.Query"]
  def process_geofence_event(user_id, attrs) do
    action = attrs["action"]

    if action in ["entered", "exited"],
      do: do_process_geofence_event(user_id, attrs, action),
      else: {:error, :invalid_action}
  end

  defp do_process_geofence_event(user_id, attrs, action) do
    geofence_id = attrs["geofence_id"]

    with {:ok, _geofence} <- validate_geofence(geofence_id, user_id) do
      location_attrs =
        attrs |> Map.put("user_id", user_id) |> Map.put("source", "geofence_event")

      case %DeviceLocation{} |> DeviceLocation.changeset(location_attrs) |> Repo.insert() do
        {:ok, location} ->
          verified = geofence_contains_location?(geofence_id, location.id)
          maybe_update_state(user_id, geofence_id, action, attrs, location, verified)
          {:ok, %{verified: verified}}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp validate_geofence(geofence_id, user_id) do
    with {:geofence, geofence} when not is_nil(geofence) <-
           {:geofence, Fence.Geofences.get_geofence(geofence_id)},
         {:expired, false} <-
           {:expired, DateTime.compare(geofence.expires_at, DateTime.utc_now()) != :gt},
         {:member, true} <-
           {:member, Groups.member?(user_id, geofence.group_id)},
         {:opted_out, false} <-
           {:opted_out, Fence.Geofences.opted_out?(user_id, geofence_id)} do
      {:ok, geofence}
    else
      {:geofence, nil} -> {:error, :not_found}
      {:expired, true} -> {:error, :expired}
      {:member, false} -> {:error, :forbidden}
      {:opted_out, true} -> {:error, :opted_out}
    end
  end

  defp maybe_update_state(user_id, geofence_id, action, attrs, _location, verified) do
    accuracy = attrs["accuracy"] || 0.0
    poor_accuracy = accuracy > 100.0

    should_trust =
      case action do
        "entered" -> verified or poor_accuracy
        "exited" -> !verified or poor_accuracy
      end

    if should_trust do
      apply_state_change(user_id, geofence_id, action)
    end
  end

  defp apply_state_change(user_id, geofence_id, action) do
    previous_ids = get_user_geofence_ids(user_id)

    {entered_ids, exited_ids} = compute_state_diff(previous_ids, geofence_id, action)

    update_geofence_state(user_id, entered_ids, exited_ids)
    enqueue_notifications(user_id, entered_ids, exited_ids)
  end

  defp compute_state_diff(previous_ids, geofence_id, "entered") do
    if MapSet.member?(previous_ids, geofence_id),
      do: {MapSet.new(), MapSet.new()},
      else: {MapSet.new([geofence_id]), MapSet.new()}
  end

  defp compute_state_diff(previous_ids, geofence_id, "exited") do
    if MapSet.member?(previous_ids, geofence_id),
      do: {MapSet.new(), MapSet.new([geofence_id])},
      else: {MapSet.new(), MapSet.new()}
  end

  defp enqueue_notifications(user_id, entered_ids, exited_ids) do
    for gid <- entered_ids do
      %{user_id: user_id, geofence_id: gid, event: "entered"}
      |> PushNotificationWorker.new()
      |> Oban.insert()
    end

    for gid <- exited_ids do
      %{user_id: user_id, geofence_id: gid, event: "exited"}
      |> PushNotificationWorker.new()
      |> Oban.insert()
    end
  end

  # sobelow_skip ["SQL.Query"]
  defp geofence_contains_location?(geofence_id, location_id) do
    query = """
    SELECT ST_Contains(g.boundary, dl.point)
    FROM geofences g, device_locations dl
    WHERE g.id = $1 AND dl.id = $2
    """

    case Repo.query(query, [Ecto.UUID.dump!(geofence_id), Ecto.UUID.dump!(location_id)]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end
