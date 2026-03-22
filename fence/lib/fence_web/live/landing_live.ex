defmodule FenceWeb.LandingLive do
  use FenceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-700 to-purple-900">
      <!-- Hero -->
      <div class="flex flex-col items-center justify-center px-4 pt-24 pb-16 text-center">
        <h1 class="text-5xl font-bold text-white mb-4">Fence</h1>
        <p class="text-xl text-purple-200 mb-8 max-w-md">
          Keep your family close. Share locations, set geofences, and get notified — all in real time.
        </p>
        <div class="flex gap-4">
          <a
            href="/web/register"
            class="rounded-lg bg-white px-6 py-3 text-sm font-semibold text-purple-700 shadow-lg hover:bg-purple-50"
          >
            Get Started
          </a>
          <a
            href="/web/login"
            class="rounded-lg border-2 border-white px-6 py-3 text-sm font-semibold text-white hover:bg-purple-800"
          >
            Sign In
          </a>
        </div>
      </div>

      <!-- Features -->
      <div class="mx-auto max-w-4xl px-4 pb-24">
        <div class="grid grid-cols-1 gap-8 md:grid-cols-3">
          <div class="rounded-lg bg-purple-800 bg-opacity-50 p-6 text-center">
            <div class="mb-3 text-3xl">📍</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Location Sharing</h3>
            <p class="text-sm text-purple-200">
              See where your family members are in real time on a shared map.
            </p>
          </div>
          <div class="rounded-lg bg-purple-800 bg-opacity-50 p-6 text-center">
            <div class="mb-3 text-3xl">🔔</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Geofence Alerts</h3>
            <p class="text-sm text-purple-200">
              Draw boundaries and get notified when someone arrives or leaves.
            </p>
          </div>
          <div class="rounded-lg bg-purple-800 bg-opacity-50 p-6 text-center">
            <div class="mb-3 text-3xl">👥</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Family Groups</h3>
            <p class="text-sm text-purple-200">
              Organize your family into groups with invite codes.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
