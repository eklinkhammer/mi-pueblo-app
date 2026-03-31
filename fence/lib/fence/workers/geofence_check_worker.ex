defmodule Fence.Workers.GeofenceCheckWorker do
  use Oban.Worker, queue: :geofence_checks, max_attempts: 3

  alias Fence.Locations
  alias Fence.Workers.PushNotificationWorker

  @dialyzer {:nowarn_function, perform: 1}
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "location_id" => location_id} = args}) do
    source = Map.get(args, "source", "foreground")

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

    # Only broadcast location to group channels for foreground reports
    if source == "foreground" do
      Locations.broadcast_location_update(user_id, location_id)
    end

    :ok
  end
end
