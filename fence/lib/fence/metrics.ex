defmodule Fence.Metrics do
  @moduledoc """
  App-level metrics: user counts and sync staleness percentiles.
  """

  import Ecto.Query
  alias Fence.Repo

  @doc "Returns total number of registered users."
  def total_user_count do
    Repo.aggregate(Fence.Accounts.User, :count)
  end

  @doc """
  Computes sync staleness percentiles across all users.
  Returns %{p50: seconds, p90: seconds} where seconds is how long
  since each user's most recent location report.
  """
  def sync_staleness_percentiles do
    now = DateTime.utc_now()

    staleness_values =
      from(l in Fence.Locations.DeviceLocation,
        distinct: l.user_id,
        order_by: [asc: l.user_id, desc: l.inserted_at],
        select: l.inserted_at
      )
      |> Repo.all()
      |> Enum.map(fn inserted_at -> DateTime.diff(now, inserted_at, :second) end)
      |> Enum.sort()

    case staleness_values do
      [] ->
        %{p50: 0, p90: 0}

      sorted ->
        len = length(sorted)

        %{
          p50: percentile_at(sorted, len, 0.50),
          p90: percentile_at(sorted, len, 0.90)
        }
    end
  end

  defp percentile_at(sorted, len, p) do
    index = max(0, round(p * len) - 1)
    Enum.at(sorted, index, 0)
  end
end
