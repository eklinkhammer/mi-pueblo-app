defmodule Fence.Locations do
  import Ecto.Query
  alias Fence.Repo
  alias Fence.Locations.{DeviceLocation, UserGeofenceState}

  def report_location(user_id, attrs) do
    location_attrs = Map.put(attrs, "user_id", user_id)

    result =
      %DeviceLocation{}
      |> DeviceLocation.changeset(location_attrs)
      |> Repo.insert()

    case result do
      {:ok, location} ->
        # Enqueue geofence check
        %{user_id: user_id, location_id: location.id}
        |> Fence.Workers.GeofenceCheckWorker.new()
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

  def get_group_last_locations(group_id) do
    from(l in DeviceLocation,
      join: m in Fence.Groups.Membership,
      on: m.user_id == l.user_id and m.group_id == ^group_id,
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

  # Geofence state management

  def get_user_geofence_ids(user_id) do
    from(s in UserGeofenceState,
      where: s.user_id == ^user_id,
      select: s.geofence_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

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
end
