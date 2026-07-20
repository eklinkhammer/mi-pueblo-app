defmodule Fence.Workers.DwellTimeWorker do
  use Oban.Worker, queue: :geofence_checks, max_attempts: 3

  require Logger

  import Ecto.Query

  alias Fence.Locations
  alias Fence.Locations.PendingGeofenceTransition
  alias Fence.Repo
  alias Fence.Workers.PushNotificationWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "geofence_id" => geofence_id}}) do
    case Repo.one(
           from(p in PendingGeofenceTransition,
             where: p.user_id == ^user_id and p.geofence_id == ^geofence_id
           )
         ) do
      nil ->
        # Transition was already cancelled or committed
        :ok

      %PendingGeofenceTransition{event: event} = pending ->
        # Verify the transition is still valid by checking current location
        current_ids = Locations.get_user_geofence_ids(user_id)
        currently_inside = MapSet.member?(current_ids, geofence_id)

        still_valid =
          case event do
            "entered" -> !currently_inside
            "exited" -> currently_inside
          end

        resolve_pending(pending, still_valid, user_id, geofence_id, event)
        :ok
    end
  end

  defp resolve_pending(pending, true = _still_valid, user_id, geofence_id, event) do
    Repo.transaction(fn ->
      commit_transition(user_id, geofence_id, event)
      Repo.delete(pending)
    end)

    Logger.info("[DwellTime] Committed #{event} for user=#{user_id} geofence=#{geofence_id}")
  end

  defp resolve_pending(pending, false = _still_valid, user_id, geofence_id, event) do
    Repo.delete(pending)

    Logger.info(
      "[DwellTime] Discarded #{event} for user=#{user_id} geofence=#{geofence_id} (contradicted)"
    )
  end

  defp commit_transition(user_id, geofence_id, "entered") do
    Locations.update_geofence_state(user_id, MapSet.new([geofence_id]), MapSet.new())

    %{user_id: user_id, geofence_id: geofence_id, event: "entered"}
    |> PushNotificationWorker.new()
    |> Oban.insert()
  end

  defp commit_transition(user_id, geofence_id, "exited") do
    Locations.update_geofence_state(user_id, MapSet.new(), MapSet.new([geofence_id]))

    %{user_id: user_id, geofence_id: geofence_id, event: "exited"}
    |> PushNotificationWorker.new()
    |> Oban.insert()
  end
end
