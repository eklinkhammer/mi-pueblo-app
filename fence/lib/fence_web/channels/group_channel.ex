defmodule FenceWeb.GroupChannel do
  use Phoenix.Channel

  alias Fence.Groups
  alias FenceWeb.Presence

  @impl true
  def join("group:" <> group_id, _params, socket) do
    user_id = socket.assigns.user_id

    if Groups.is_member?(user_id, group_id) do
      send(self(), :after_join)
      {:ok, assign(socket, :group_id, group_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id
    user = Fence.Accounts.get_user(user_id)

    {:ok, _} =
      Presence.track(socket, user_id, %{
        display_name: user && user.display_name,
        online_at: System.system_time(:second)
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  @impl true
  def handle_in("location:update", params, socket) do
    user_id = socket.assigns.user_id

    case Fence.Locations.report_location(user_id, params) do
      {:ok, _} -> {:reply, :ok, socket}
      {:error, _} -> {:reply, {:error, %{reason: "invalid_location"}}, socket}
    end
  end
end
