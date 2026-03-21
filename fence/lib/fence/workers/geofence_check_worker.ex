defmodule Fence.Workers.GeofenceCheckWorker do
  use Oban.Worker, queue: :geofence_checks, max_attempts: 3

  alias Fence.{Accounts, Groups, Locations}
  alias Fence.Locations.DeviceLocation
  alias Fence.Repo
  alias Fence.Workers.PushNotificationWorker

  @dialyzer {:nowarn_function, perform: 1}
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "location_id" => location_id}}) do
    # Get current geofence state
    previous_ids = Locations.get_user_geofence_ids(user_id)

    # Find which geofences contain the new location
    current_ids = Locations.find_containing_geofences(user_id, location_id)

    # Compute entries and exits
    entered_ids = MapSet.difference(current_ids, previous_ids)
    exited_ids = MapSet.difference(previous_ids, current_ids)

    # Update state
    Locations.update_geofence_state(user_id, entered_ids, exited_ids)

    # Enqueue notifications for each entry/exit
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

    # Broadcast location update to group channels
    broadcast_location_update(user_id, location_id)

    :ok
  end

  defp broadcast_location_update(user_id, location_id) do
    location = Repo.get(DeviceLocation, location_id)

    if location do
      # Get all groups the user belongs to
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
end
