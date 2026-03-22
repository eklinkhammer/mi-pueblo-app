defmodule FenceWeb.LandingLive do
  use FenceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-purple-700 to-purple-900 flex flex-col">
      <!-- Hero -->
      <div class="flex flex-col items-center justify-center px-4 pt-28 pb-20 text-center flex-grow">
        <h1 class="text-6xl font-extrabold text-white tracking-tight mb-6">Fence</h1>
        <p class="text-xl text-purple-200 mb-10 max-w-lg leading-relaxed">
          Keep your family close. Share locations, set geofences, and get notified — all in real time.
        </p>
        <div class="flex gap-4">
          <a
            href="/web/register"
            class="rounded-lg bg-white px-8 py-3 text-sm font-semibold text-purple-700 shadow-lg hover:bg-purple-50 transition"
          >
            Get Started
          </a>
          <a
            href="/web/login"
            class="rounded-lg border-2 border-white px-8 py-3 text-sm font-semibold text-white hover:bg-white/10 transition"
          >
            Sign In
          </a>
        </div>
      </div>

      <!-- Features -->
      <div class="mx-auto max-w-4xl px-4 pb-20">
        <div class="grid grid-cols-1 gap-6 md:grid-cols-3">
          <div class="rounded-xl bg-white/10 backdrop-blur-sm p-8 text-center shadow-lg">
            <div class="mb-4 text-4xl">📍</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Location Sharing</h3>
            <p class="text-sm text-purple-200 leading-relaxed">
              See where your family members are in real time on a shared map.
            </p>
          </div>
          <div class="rounded-xl bg-white/10 backdrop-blur-sm p-8 text-center shadow-lg">
            <div class="mb-4 text-4xl">🔔</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Geofence Alerts</h3>
            <p class="text-sm text-purple-200 leading-relaxed">
              Draw boundaries and get notified when someone arrives or leaves.
            </p>
          </div>
          <div class="rounded-xl bg-white/10 backdrop-blur-sm p-8 text-center shadow-lg">
            <div class="mb-4 text-4xl">👥</div>
            <h3 class="mb-2 text-lg font-semibold text-white">Family Groups</h3>
            <p class="text-sm text-purple-200 leading-relaxed">
              Organize your family into groups with invite codes.
            </p>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <footer class="py-6 text-center text-sm text-purple-300/60">
        Fence &mdash; Family location sharing
      </footer>
    </div>
    """
  end
end
