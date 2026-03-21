defmodule FenceWeb.MapLive do
  use FenceWeb, :live_view

  alias Fence.{Geofences, Groups, Locations}

  @refresh_interval :timer.seconds(10)

  @impl true
  def mount(_params, _session, socket) do
    groups = Groups.list_user_groups(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:groups, groups)
      |> assign(:selected_group_id, nil)
      |> assign(:locations, [])
      |> assign(:geofences, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_group", %{"group_id" => group_id}, socket) do
    socket =
      socket
      |> assign(:selected_group_id, group_id)
      |> load_data(group_id)
      |> schedule_refresh()

    {:noreply, socket}
  end

  def handle_event("geofence_clicked", %{"id" => id, "group_id" => group_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/web/groups/#{group_id}/geofences/#{id}")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    case socket.assigns.selected_group_id do
      nil ->
        {:noreply, socket}

      group_id ->
        socket =
          socket
          |> load_data(group_id)
          |> schedule_refresh()

        {:noreply, socket}
    end
  end

  defp load_data(socket, group_id) do
    locations = Locations.get_group_last_locations(group_id)
    geofences = Geofences.list_active_group_geofences(group_id)

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

    geofence_data =
      Enum.map(geofences, fn gf ->
        {lng, lat} = gf.center.coordinates

        %{
          id: gf.id,
          group_id: gf.group_id,
          name: gf.name,
          lat: lat,
          lng: lng,
          radius: gf.radius_meters
        }
      end)

    bounds =
      Enum.map(location_data, &[&1.lat, &1.lng]) ++
        Enum.map(geofence_data, &[&1.lat, &1.lng])

    socket
    |> assign(:locations, location_data)
    |> assign(:geofences, geofence_data)
    |> push_event("update_locations", %{locations: location_data})
    |> push_event("update_geofences", %{geofences: geofence_data})
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
        <h1 class="text-2xl font-bold">Map</h1>
        <div class="flex items-center gap-4">
          <form phx-change="select_group">
            <select name="group_id" class="rounded-md border border-gray-300 px-3 py-2 text-sm">
              <option value="">Select a group</option>
              <option :for={group <- @groups} value={group.id} selected={group.id == @selected_group_id}>
                {group.name}
              </option>
            </select>
          </form>
          <.link
            :if={@selected_group_id}
            navigate={~p"/web/groups/#{@selected_group_id}/geofences/new"}
            class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold text-white hover:bg-blue-700"
          >
            + Geofence
          </.link>
        </div>
      </div>

      <div :if={@selected_group_id == nil} class="flex items-center justify-center h-96 bg-gray-100 rounded-lg">
        <p class="text-gray-500">Select a group to view the map</p>
      </div>

      <div :if={@selected_group_id} class="flex gap-4">
        <div
          id="map"
          phx-hook="LeafletMap"
          data-interactive="false"
          class="h-[500px] flex-1 rounded-lg border border-gray-200"
          phx-update="ignore"
        >
        </div>
        <div class="w-64 space-y-2">
          <h3 class="font-semibold text-sm text-gray-700">Members</h3>
          <div :for={loc <- @locations} class="text-sm">
            <span class="font-medium">{loc.display_name}</span>
            <span class="text-gray-500 ml-1">{loc.time_ago}</span>
          </div>
          <div :if={@locations == []} class="text-sm text-gray-400">No locations yet</div>

          <h3 class="font-semibold text-sm text-gray-700 mt-4">Geofences</h3>
          <div :for={gf <- @geofences} class="text-sm">
            <.link
              navigate={~p"/web/groups/#{gf.group_id}/geofences/#{gf.id}"}
              class="text-blue-600 hover:underline"
            >
              {gf.name}
            </.link>
            <span class="text-gray-500 ml-1">{round_radius(gf.radius)}m</span>
          </div>
          <div :if={@geofences == []} class="text-sm text-gray-400">No geofences</div>
        </div>
      </div>
    </div>
    """
  end

  defp round_radius(val) when is_float(val), do: Float.round(val) |> trunc()
  defp round_radius(val), do: val
end
