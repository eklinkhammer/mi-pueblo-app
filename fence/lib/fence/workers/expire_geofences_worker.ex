defmodule Fence.Workers.ExpireGeofencesWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 3

  import Ecto.Query
  alias Fence.Repo
  alias Fence.Geofences.Geofence

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    now = DateTime.utc_now()

    {count, _} =
      from(g in Geofence, where: g.expires_at <= ^now)
      |> Repo.delete_all()

    if count > 0 do
      Logger.info("Expired #{count} geofences")
    end

    :ok
  end
end
