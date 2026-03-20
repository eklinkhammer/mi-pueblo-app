defmodule Fence.Workers.MergeGeofencesWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  alias Fence.Geofences.MergeEngine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"group_id" => group_id}}) do
    MergeEngine.merge_group_geofences(group_id)
    :ok
  end
end
