defmodule Fence.Workers.CleanupPasswordResetCodesWorker do
  use Oban.Worker, queue: :maintenance, max_attempts: 1

  import Ecto.Query
  alias Fence.Accounts.PasswordResetCode
  alias Fence.Repo

  @impl Oban.Worker
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-24 * 60 * 60)

    from(r in PasswordResetCode, where: r.expires_at < ^cutoff)
    |> Repo.delete_all()

    :ok
  end
end
