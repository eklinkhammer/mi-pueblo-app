defmodule FenceWeb.DashboardLive do
  use FenceWeb, :live_view

  alias Fence.{Groups, Locations}
  alias Fence.Metrics
  alias Fence.Metrics.Collector

  @refresh_interval :timer.seconds(10)

  @impl true
  def mount(_params, _session, socket) do
    groups = Groups.list_user_groups(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:groups, groups)
      |> assign(:selected_group_id, nil)
      |> assign(:locations, [])
      |> assign(:total_users, 0)
      |> assign(:staleness, %{p50: 0, p90: 0})
      |> assign(:vm_memory_mb, 0.0)
      |> assign(:process_count, 0)
      |> assign(:atom_count, 0)
      |> assign(:request_latency, %{p50: 0, p90: 0, p99: 0})
      |> assign(:db_query, %{p50: 0, p90: 0, p99: 0})
      |> assign(:db_queue, %{p50: 0, p90: 0, p99: 0})
      |> load_data()
      |> schedule_refresh()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_group", %{"group_id" => ""}, socket) do
    socket =
      socket
      |> assign(:selected_group_id, nil)
      |> load_data()

    {:noreply, socket}
  end

  def handle_event("select_group", %{"group_id" => group_id}, socket) do
    socket =
      socket
      |> assign(:selected_group_id, group_id)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> load_data()
      |> schedule_refresh()

    {:noreply, socket}
  end

  defp load_data(socket) do
    socket
    |> load_locations()
    |> load_metrics()
  end

  defp load_locations(socket) do
    locations =
      case socket.assigns.selected_group_id do
        nil -> Locations.get_all_last_locations()
        group_id -> Locations.get_group_last_locations(group_id)
      end

    location_data =
      Enum.map(locations, fn loc ->
        {lng, lat} = loc.point.coordinates

        %{
          user_id: loc.user_id,
          display_name: loc.display_name || "Unknown",
          lat: lat,
          lng: lng,
          time_ago: time_ago(loc.updated_at)
        }
      end)

    bounds = Enum.map(location_data, &[&1.lat, &1.lng])

    socket
    |> assign(:locations, location_data)
    |> push_event("update_locations", %{locations: location_data})
    |> maybe_fit_bounds(bounds)
  end

  defp load_metrics(socket) do
    socket
    |> assign(:total_users, Metrics.total_user_count())
    |> assign(:staleness, Metrics.sync_staleness_percentiles())
    |> assign(:vm_memory_mb, Float.round(:erlang.memory(:total) / 1_048_576, 1))
    |> assign(:process_count, :erlang.system_info(:process_count))
    |> assign(:atom_count, :erlang.system_info(:atom_count))
    |> assign(:request_latency, Collector.get_request_latency_percentiles())
    |> assign(:db_query, Collector.get_db_query_percentiles())
    |> assign(:db_queue, Collector.get_db_queue_percentiles())
  end

  defp maybe_fit_bounds(socket, []), do: socket

  defp maybe_fit_bounds(socket, bounds) do
    push_event(socket, "fit_bounds", %{bounds: bounds})
  end

  defp schedule_refresh(socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, @refresh_interval)
    socket
  end

  defp selected_group_name(_groups, nil), do: "All Users"

  defp selected_group_name(groups, group_id) do
    case Enum.find(groups, &(&1.id == group_id)) do
      nil -> "All Users"
      group -> group.name
    end
  end

  defp format_staleness(seconds) when is_number(seconds) do
    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m"
      seconds < 86_400 -> "#{div(seconds, 3600)}h"
      true -> "#{div(seconds, 86_400)}d"
    end
  end

  defp format_staleness(_), do: "N/A"

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_number(n), do: to_string(n)

  attr :title, :string, required: true
  attr :value, :string, required: true

  defp metric_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div class="text-xs font-medium text-gray-500 uppercase tracking-wide">{@title}</div>
      <div class="mt-1 text-lg font-semibold text-gray-900">{@value}</div>
    </div>
    """
  end

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <form phx-change="select_group">
          <select name="group_id" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
            <option value="">All Users</option>
            <option :for={group <- @groups} value={group.id} selected={group.id == @selected_group_id}>
              {group.name}
            </option>
          </select>
        </form>
      </div>

      <%!-- Row 1: App metrics --%>
      <div class="grid grid-cols-3 gap-4">
        <.metric_card title="Total Users" value={format_number(@total_users)} />
        <.metric_card title="Staleness p50" value={format_staleness(@staleness.p50)} />
        <.metric_card title="Staleness p90" value={format_staleness(@staleness.p90)} />
      </div>

      <%!-- Row 2: VM metrics --%>
      <div class="grid grid-cols-3 gap-4">
        <.metric_card title="VM Memory" value={"#{@vm_memory_mb} MB"} />
        <.metric_card title="Processes" value={format_number(@process_count)} />
        <.metric_card title="Atoms" value={format_number(@atom_count)} />
      </div>

      <%!-- Row 3: Latency metrics --%>
      <div class="grid grid-cols-3 gap-4">
        <.metric_card
          title="Request Latency (ms)"
          value={"p50:#{@request_latency.p50} p90:#{@request_latency.p90} p99:#{@request_latency.p99}"}
        />
        <.metric_card
          title="DB Query Time (ms)"
          value={"p50:#{@db_query.p50} p90:#{@db_query.p90} p99:#{@db_query.p99}"}
        />
        <.metric_card
          title="DB Queue Wait (ms)"
          value={"p50:#{@db_queue.p50} p90:#{@db_queue.p90} p99:#{@db_queue.p99}"}
        />
      </div>

      <div class="flex gap-4">
        <div
          id="map"
          phx-hook="LeafletMap"
          data-interactive="false"
          style="height:600px"
          class="flex-1 rounded-lg border border-gray-200"
          phx-update="ignore"
        >
        </div>
        <div class="w-64 space-y-2">
          <h3 class="font-semibold text-sm text-gray-700">
            {selected_group_name(@groups, @selected_group_id)}
          </h3>
          <div :for={loc <- @locations} class="text-sm">
            <span class="font-medium">{loc.display_name}</span>
            <span class="text-gray-500 ml-1">{loc.time_ago}</span>
          </div>
          <div :if={@locations == []} class="text-sm text-gray-400">No locations yet</div>
        </div>
      </div>
    </div>
    """
  end
end
