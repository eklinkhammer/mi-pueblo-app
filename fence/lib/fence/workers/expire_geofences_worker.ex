defmodule Fence.Workers.ExpireGeofencesWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query
  alias Fence.Geofences.Geofence
  alias Fence.Repo

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    # Get affected group IDs before deleting
    affected_group_ids =
      from(g in Geofence,
        where: g.expires_at <= ^now,
        select: g.group_id,
        distinct: true
      )
      |> Repo.all()

    {count, _} =
      from(g in Geofence, where: g.expires_at <= ^now)
      |> Repo.delete_all()

    if count > 0 do
      Logger.info("Expired #{count} geofences")

      for group_id <- affected_group_ids do
        FenceWeb.Endpoint.broadcast("group:#{group_id}", "geofences:changed", %{})
      end
    end

    :ok
  end
end
