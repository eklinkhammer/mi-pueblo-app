defmodule FenceWeb.GeofenceDetailLive do
  use FenceWeb, :live_view

  alias Fence.Geofences

  @impl true
  def mount(%{"group_id" => group_id, "id" => id}, _session, socket) do
    user = socket.assigns.current_user
    geofence = Geofences.get_geofence(id)

    if geofence == nil || geofence.group_id != group_id do
      {:ok,
       socket
       |> put_flash(:error, "Geofence not found")
       |> push_navigate(to: ~p"/web/map")}
    else
      subscription = Geofences.get_subscription(user.id, id)
      opted_out = Geofences.opted_out?(user.id, id)
      {lng, lat} = geofence.center.coordinates

      socket =
        socket
        |> assign(:group_id, group_id)
        |> assign(:geofence, geofence)
        |> assign(:lat, lat)
        |> assign(:lng, lng)
        |> assign(:subscription, subscription)
        |> assign(:opted_out, opted_out)
        |> assign(:notify_on_entry, (subscription && subscription.notify_on_entry) || false)
        |> assign(:notify_on_exit, (subscription && subscription.notify_on_exit) || false)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_entry", _params, socket) do
    new_val = !socket.assigns.notify_on_entry

    save_subscription(socket, %{
      notify_on_entry: new_val,
      notify_on_exit: socket.assigns.notify_on_exit
    })

    {:noreply, assign(socket, :notify_on_entry, new_val)}
  end

  def handle_event("toggle_exit", _params, socket) do
    new_val = !socket.assigns.notify_on_exit

    save_subscription(socket, %{
      notify_on_entry: socket.assigns.notify_on_entry,
      notify_on_exit: new_val
    })

    {:noreply, assign(socket, :notify_on_exit, new_val)}
  end

  def handle_event("toggle_opt_out", _params, socket) do
    user = socket.assigns.current_user
    gf = socket.assigns.geofence

    if socket.assigns.opted_out do
      Geofences.delete_opt_out(user.id, gf.id)
      {:noreply, assign(socket, :opted_out, false)}
    else
      Geofences.create_opt_out(user.id, gf.id)
      {:noreply, assign(socket, :opted_out, true)}
    end
  end

  def handle_event("delete", _params, socket) do
    gf = socket.assigns.geofence

    case Geofences.delete_geofence(gf) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Geofence deleted")
         |> push_navigate(to: ~p"/web/map")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete")}
    end
  end

  defp save_subscription(socket, attrs) do
    user = socket.assigns.current_user
    gf = socket.assigns.geofence

    Geofences.upsert_subscription(Map.merge(attrs, %{user_id: user.id, geofence_id: gf.id}))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/web/map"} class="text-blue-600 hover:underline text-sm">&larr; Back to map</.link>
          <h1 class="text-2xl font-bold">{@geofence.name}</h1>
        </div>
        <button
          phx-click="delete"
          data-confirm="Are you sure you want to delete this geofence?"
          class="rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700"
        >
          Delete
        </button>
      </div>

      <div
        id="detail-map"
        phx-hook="LeafletMap"
        data-static="true"
        class="h-64 rounded-lg border border-gray-200"
        phx-update="ignore"
      >
      </div>
      <script>
        // Set view for static detail map after hook mounts
        window.addEventListener("phx:page-loading-stop", function detailInit() {
          window.removeEventListener("phx:page-loading-stop", detailInit);
          if (window.liveSocket) {
            const hook = document.getElementById("detail-map")?.__phxHook;
            if (hook && hook.map) {
              const lat = <%= @lat %>;
              const lng = <%= @lng %>;
              const radius = <%= @geofence.radius_meters %>;
              hook.map.setView([lat, lng], 15);
              L.circle([lat, lng], {radius: radius, color: "#3b82f6", fillColor: "#3b82f6", fillOpacity: 0.1, weight: 2}).addTo(hook.map);
              L.marker([lat, lng]).addTo(hook.map);
              setTimeout(() => hook.map.invalidateSize(), 200);
            }
          }
        });
      </script>

      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="font-medium text-gray-700">Radius</span>
          <p>{Float.round(@geofence.radius_meters, 0) |> trunc()} meters</p>
        </div>
        <div :if={@geofence.description}>
          <span class="font-medium text-gray-700">Description</span>
          <p>{@geofence.description}</p>
        </div>
      </div>

      <div class="border-t pt-4">
        <h2 class="font-semibold mb-3">Notifications</h2>
        <div class="space-y-2">
          <label class="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={@notify_on_entry}
              phx-click="toggle_entry"
              class="rounded border-gray-300"
            />
            <span class="text-sm">Notify on entry</span>
          </label>
          <label class="flex items-center gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={@notify_on_exit}
              phx-click="toggle_exit"
              class="rounded border-gray-300"
            />
            <span class="text-sm">Notify on exit</span>
          </label>
        </div>
      </div>

      <div class="border-t pt-4">
        <label class="flex items-center gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={@opted_out}
            phx-click="toggle_opt_out"
            class="rounded border-gray-300"
          />
          <div>
            <span class="text-sm font-medium">Opt out of this geofence</span>
            <p class="text-xs text-gray-500">Your location won't trigger notifications for this fence</p>
          </div>
        </label>
      </div>
    </div>
    """
  end
end
