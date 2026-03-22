defmodule FenceWeb.LoginLive do
  use FenceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center bg-gradient-to-br from-purple-700 to-purple-900 px-4">
      <div class="w-full max-w-sm rounded-xl bg-white p-8 shadow-2xl">
        <h2 class="mb-6 text-center text-2xl font-bold text-purple-700">Sign In</h2>

        <.flash_group flash={@flash} />

        <form action="/web/auth/login" method="post" class="space-y-4">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

          <div>
            <label class="mb-1 block text-sm font-medium text-gray-700">Email</label>
            <input
              type="email"
              name="email"
              required
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
            />
          </div>

          <div>
            <label class="mb-1 block text-sm font-medium text-gray-700">Password</label>
            <input
              type="password"
              name="password"
              required
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500/20"
            />
          </div>

          <button
            type="submit"
            class="w-full rounded-lg bg-purple-600 px-4 py-2.5 text-sm font-semibold text-white shadow-lg hover:bg-purple-700 transition"
          >
            Sign In
          </button>
        </form>

        <p class="mt-6 text-center text-sm text-gray-500">
          Don't have an account?
          <a href="/web/register" class="font-medium text-purple-600 hover:underline">Register</a>
        </p>
      </div>
    </div>
    """
  end
end
