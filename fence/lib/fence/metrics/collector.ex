defmodule Fence.Metrics.Collector do
  @moduledoc """
  GenServer that attaches to Phoenix and Ecto telemetry events, stores
  measurements in a sliding window (last 1000 per metric), and computes
  percentiles on demand.
  """

  use GenServer

  @table :fence_metrics_collector
  @max_entries 1000
  @prune_interval :timer.seconds(60)

  # ── Public API ──────────────────────────────────────────────────────

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns %{p50: ms, p90: ms, p99: ms} for request latency."
  def get_request_latency_percentiles do
    get_percentiles(:request_latency)
  end

  @doc "Returns %{p50: ms, p90: ms, p99: ms} for DB query time."
  def get_db_query_percentiles do
    get_percentiles(:db_query_time)
  end

  @doc "Returns %{p50: ms, p90: ms, p99: ms} for DB queue wait time."
  def get_db_queue_percentiles do
    get_percentiles(:db_queue_time)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :ordered_set])

    # Initialize counters for each metric
    for metric <- [:request_latency, :db_query_time, :db_queue_time] do
      :ets.insert(table, {{metric, :counter}, 0})
    end

    attach_handlers()
    schedule_prune()

    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:prune, state) do
    prune_old_entries()
    schedule_prune()
    {:noreply, state}
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp attach_handlers do
    :telemetry.attach(
      "fence-metrics-endpoint-stop",
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_endpoint_stop/4,
      nil
    )

    :telemetry.attach(
      "fence-metrics-repo-query",
      [:fence, :repo, :query],
      &__MODULE__.handle_repo_query/4,
      nil
    )
  end

  def handle_endpoint_stop(_event, measurements, _metadata, _config) do
    case measurements do
      %{duration: duration} when is_integer(duration) ->
        ms = System.convert_time_unit(duration, :native, :millisecond)
        record_measurement(:request_latency, ms)

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end

  def handle_repo_query(_event, measurements, _metadata, _config) do
    if is_map(measurements) do
      if is_integer(measurements[:query_time]) do
        ms = System.convert_time_unit(measurements.query_time, :native, :millisecond)
        record_measurement(:db_query_time, ms)
      end

      if is_integer(measurements[:queue_time]) do
        ms = System.convert_time_unit(measurements.queue_time, :native, :millisecond)
        record_measurement(:db_queue_time, ms)
      end
    end
  rescue
    _ -> :ok
  end

  defp record_measurement(metric, value) do
    counter = :ets.update_counter(@table, {metric, :counter}, {2, 1})
    :ets.insert(@table, {{metric, counter}, value})
  rescue
    _ -> :ok
  end

  defp get_percentiles(metric) do
    values =
      :ets.match(@table, {{metric, :"$1"}, :"$2"})
      |> Enum.reject(fn [key, _] -> key == :counter end)
      |> Enum.map(fn [_, value] -> value end)
      |> Enum.sort()

    case values do
      [] ->
        %{p50: 0, p90: 0, p99: 0}

      sorted ->
        len = length(sorted)

        %{
          p50: percentile_at(sorted, len, 0.50),
          p90: percentile_at(sorted, len, 0.90),
          p99: percentile_at(sorted, len, 0.99)
        }
    end
  rescue
    _ -> %{p50: 0, p90: 0, p99: 0}
  end

  defp percentile_at(sorted, len, p) do
    index = max(0, round(p * len) - 1)
    Enum.at(sorted, index, 0)
  end

  defp prune_old_entries do
    for metric <- [:request_latency, :db_query_time, :db_queue_time] do
      prune_metric(metric)
    end
  rescue
    _ -> :ok
  end

  defp prune_metric(metric) do
    entries =
      :ets.match(@table, {{metric, :"$1"}, :"$2"})
      |> Enum.reject(fn [key, _] -> key == :counter end)
      |> Enum.sort_by(fn [key, _] -> key end)

    overflow = length(entries) - @max_entries

    if overflow > 0 do
      entries
      |> Enum.take(overflow)
      |> Enum.each(fn [key, _] -> :ets.delete(@table, {metric, key}) end)
    end
  end

  defp schedule_prune do
    Process.send_after(self(), :prune, @prune_interval)
  end
end
