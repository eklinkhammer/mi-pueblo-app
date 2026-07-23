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
      |> assign(:tracked_users, 0)
      |> assign(:active_users, 0)
      |> assign(:notification_stats, %{sent_today: 0, sent_hour: 0, errors_today: 0, errors_hour: 0})
      |> assign(:group_count, 0)
      |> assign(:active_geofences, 0)
      |> assign(:geofence_events_today, 0)
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
        group_id -> Locations.get_group_last_locations(group_id, socket.assigns.current_user.id)
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
    notification_stats = Metrics.notification_stats()

    socket
    |> assign(:total_users, Metrics.total_user_count())
    |> assign(:tracked_users, Metrics.tracked_user_count())
    |> assign(:active_users, Metrics.active_user_count())
    |> assign(:notification_stats, notification_stats)
    |> assign(:group_count, Metrics.group_count())
    |> assign(:active_geofences, Metrics.active_geofence_count())
    |> assign(:geofence_events_today, Metrics.geofence_events_today())
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
  attr :color, :string, default: nil
  attr :subtitle, :string, default: nil

  defp metric_card(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border p-4 shadow-sm",
      color_classes(@color)
    ]}>
      <div class="text-xs font-medium uppercase tracking-wide" style={label_style(@color)}>{@title}</div>
      <div class="mt-1 text-lg font-semibold" style={value_style(@color)}>{@value}</div>
      <div :if={@subtitle} class="mt-0.5 text-xs text-gray-400">{@subtitle}</div>
    </div>
    """
  end

  defp color_classes(nil), do: "border-gray-200 bg-white"
  defp color_classes("green"), do: "border-emerald-200 bg-emerald-50"
  defp color_classes("blue"), do: "border-blue-200 bg-blue-50"
  defp color_classes("red"), do: "border-red-200 bg-red-50"
  defp color_classes("amber"), do: "border-amber-200 bg-amber-50"
  defp color_classes(_), do: "border-gray-200 bg-white"

  defp label_style(nil), do: "color: #6b7280"
  defp label_style("green"), do: "color: #047857"
  defp label_style("blue"), do: "color: #1d4ed8"
  defp label_style("red"), do: "color: #b91c1c"
  defp label_style("amber"), do: "color: #b45309"
  defp label_style(_), do: "color: #6b7280"

  defp value_style(nil), do: "color: #111827"
  defp value_style("green"), do: "color: #065f46"
  defp value_style("blue"), do: "color: #1e3a5f"
  defp value_style("red"), do: "color: #991b1b"
  defp value_style("amber"), do: "color: #92400e"
  defp value_style(_), do: "color: #111827"

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

      <%!-- Row 1: User KPIs --%>
      <div class="grid grid-cols-3 gap-4">
        <.metric_card title="Total Users" value={format_number(@total_users)} />
        <.metric_card title="Tracked Users" value={format_number(@tracked_users)} color="green" subtitle="last 7 days" />
        <.metric_card title="Active Users" value={format_number(@active_users)} color="blue" subtitle="last 1 hour" />
      </div>

      <%!-- Row 2: Notifications --%>
      <div class="grid grid-cols-4 gap-4">
        <.metric_card title="Sent (today)" value={format_number(@notification_stats.sent_today)} />
        <.metric_card title="Sent (last hour)" value={format_number(@notification_stats.sent_hour)} />
        <.metric_card title="Errors (today)" value={format_number(@notification_stats.errors_today)} color="red" />
        <.metric_card title="Errors (last hour)" value={format_number(@notification_stats.errors_hour)} color="red" />
      </div>

      <%!-- Row 3: Platform KPIs --%>
      <div class="grid grid-cols-3 gap-4">
        <.metric_card title="Total Groups" value={format_number(@group_count)} />
        <.metric_card title="Active Geofences" value={format_number(@active_geofences)} />
        <.metric_card title="Geofence Events Today" value={format_number(@geofence_events_today)} />
      </div>

      <%!-- Row 4: System metrics --%>
      <div class="grid grid-cols-4 gap-4">
        <.metric_card
          title="Staleness"
          value={"p50: #{format_staleness(@staleness.p50)} / p90: #{format_staleness(@staleness.p90)}"}
        />
        <.metric_card
          title="Request Latency (ms)"
          value={"p50:#{@request_latency.p50} p90:#{@request_latency.p90} p99:#{@request_latency.p99}"}
        />
        <.metric_card
          title="DB Query / Queue (ms)"
          value={"Q #{@db_query.p50}/#{@db_query.p90}/#{@db_query.p99} | W #{@db_queue.p50}/#{@db_queue.p90}/#{@db_queue.p99}"}
        />
        <.metric_card
          title="VM"
          value={"#{@vm_memory_mb}MB / #{format_number(@process_count)} procs"}
        />
      </div>

      <%!-- Row 5: Map + sidebar --%>
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
