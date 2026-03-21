defmodule FenceWeb.GeofenceCreateLive do
  use FenceWeb, :live_view

  alias Fence.Geofences

  @impl true
  def mount(%{"group_id" => group_id}, _session, socket) do
    socket =
      socket
      |> assign(:group_id, group_id)
      |> assign(:name, "")
      |> assign(:radius, 200)
      |> assign(:selected_lat, nil)
      |> assign(:selected_lng, nil)
      |> assign(:saving, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("map_clicked", %{"lat" => lat, "lng" => lng}, socket) do
    socket =
      socket
      |> assign(:selected_lat, lat)
      |> assign(:selected_lng, lng)
      |> push_event("set_selected_location", %{
        lat: lat,
        lng: lng,
        radius: socket.assigns.radius
      })

    {:noreply, socket}
  end

  def handle_event("validate", %{"name" => name, "radius" => radius_str}, socket) do
    radius = parse_radius(radius_str)

    socket = assign(socket, name: name, radius: radius)

    socket =
      if socket.assigns.selected_lat do
        push_event(socket, "set_selected_location", %{
          lat: socket.assigns.selected_lat,
          lng: socket.assigns.selected_lng,
          radius: radius
        })
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("create", _params, socket) do
    %{name: name, radius: radius, selected_lat: lat, selected_lng: lng, group_id: group_id} =
      socket.assigns

    user = socket.assigns.current_user

    cond do
      String.trim(name) == "" ->
        {:noreply, put_flash(socket, :error, "Name is required")}

      lat == nil ->
        {:noreply, put_flash(socket, :error, "Tap the map to select a location")}

      true ->
        socket = assign(socket, :saving, true)
        expires_at = DateTime.utc_now() |> DateTime.add(30 * 86_400) |> DateTime.truncate(:second)

        attrs = %{
          "name" => String.trim(name),
          "latitude" => lat,
          "longitude" => lng,
          "radius_meters" => radius,
          "group_id" => group_id,
          "created_by_id" => user.id,
          "expires_at" => expires_at
        }

        case Geofences.create_geofence(attrs) do
          {:ok, _geofence} ->
            socket =
              socket
              |> put_flash(:info, "Geofence created")
              |> push_navigate(to: ~p"/web/map")

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(:saving, false)
             |> put_flash(:error, "Failed to create geofence")}
        end
    end
  end

  defp parse_radius(str) do
    case Float.parse(str) do
      {val, _} when val > 0 -> val
      _ -> 200
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center gap-4">
        <.link navigate={~p"/web/map"} class="text-blue-600 hover:underline text-sm">&larr; Back to map</.link>
        <h1 class="text-2xl font-bold">Create Geofence</h1>
      </div>

      <form phx-change="validate" phx-submit="create" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
          <input
            type="text"
            name="name"
            value={@name}
            placeholder="e.g., Home, School, Office"
            class="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Radius (meters)</label>
          <input
            type="number"
            name="radius"
            value={@radius}
            min="1"
            max="50000"
            class="block w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
          />
        </div>

        <p class="text-sm text-gray-500">Click the map to place the geofence center</p>

        <div
          id="create-map"
          phx-hook="LeafletMap"
          data-interactive="true"
          class="h-[400px] rounded-lg border border-gray-200"
          phx-update="ignore"
        >
        </div>

        <div :if={@selected_lat} class="text-sm text-gray-600">
          Selected: {Float.round(@selected_lat, 5)}, {Float.round(@selected_lng, 5)}
        </div>

        <button
          type="submit"
          disabled={@saving}
          class="rounded-lg bg-blue-600 px-6 py-2 text-sm font-semibold text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {if @saving, do: "Creating...", else: "Create Geofence"}
        </button>
      </form>
    </div>
    """
  end
end
