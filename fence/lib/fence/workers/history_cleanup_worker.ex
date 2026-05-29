defmodule Fence.Workers.HistoryCleanupWorker do
  use Oban.Worker, queue: :maintenance

  import Ecto.Query
  alias Fence.Notifications.PushLog
  alias Fence.Subscriptions.Subscription
  alias Fence.Repo

  @impl Oban.Worker
  def perform(_job) do
    # Delete push logs older than the user's tier retention
    # Free tier: 7 days, paid tiers: 90 days
    now = DateTime.utc_now()

    # Get all users with subscriptions that have active/grace_period status
    paid_user_ids =
      from(s in Subscription,
        where: s.status in ["active", "grace_period"] and s.tier != "village_member",
        select: s.user_id
      )
      |> Repo.all()

    # For paid users: delete logs older than 90 days
    paid_cutoff = DateTime.add(now, -90 * 24 * 3600, :second)

    if paid_user_ids != [] do
      from(p in PushLog,
        where: p.recipient_id in ^paid_user_ids and p.inserted_at < ^paid_cutoff
      )
      |> Repo.delete_all()
    end

    # For free users (everyone else): delete logs older than 7 days
    free_cutoff = DateTime.add(now, -7 * 24 * 3600, :second)

    from(p in PushLog,
      where: p.recipient_id not in ^paid_user_ids and p.inserted_at < ^free_cutoff
    )
    |> Repo.delete_all()

    :ok
  end
end
