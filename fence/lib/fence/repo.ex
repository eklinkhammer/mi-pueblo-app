defmodule Fence.Repo do
  use Ecto.Repo,
    otp_app: :fence,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    {:ok, Keyword.put(config, :types, Fence.PostgresTypes)}
  end
end
