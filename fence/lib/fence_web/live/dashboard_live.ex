defmodule FenceWeb.DashboardLive do
  use FenceWeb, :live_view

  alias Fence.{Groups, Locations}

  @refresh_interval :timer.seconds(10)

  @impl true
  def mount(_params, _session, socket) do
    groups = Groups.list_user_groups(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:groups, groups)
      |> assign(:selected_group_id, nil)
      |> assign(:locations, [])
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
