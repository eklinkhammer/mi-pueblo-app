defmodule FenceWeb.HistoryController do
  use FenceWeb, :controller

  alias Fence.{Groups, Locations, Subscriptions}

  def show(conn, %{"user_id" => user_id}) do
    current_user = conn.assigns.current_user

    with {:ok, _} <- Ecto.UUID.cast(user_id),
         {:authorized, group_ids} when group_ids != [] <- authorize(current_user.id, user_id) do
      retention_days = Subscriptions.history_retention_days(current_user.id)
      cutoff = DateTime.add(DateTime.utc_now(), -retention_days * 24 * 3600, :second)

      events =
        Locations.list_user_geofence_events(user_id, group_ids)
        |> Enum.filter(fn e -> DateTime.compare(e.inserted_at, cutoff) != :lt end)

      json(conn, %{
        events:
          Enum.map(events, fn e ->
            %{
              id: e.id,
              event: e.event,
              geofence_id: e.geofence_id,
              geofence_name: e.geofence_name,
              inserted_at: e.inserted_at
            }
          end)
      })
    else
      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "invalid_id", message: "Invalid user ID format"}})

      {:authorized, []} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{code: "forbidden", message: "Forbidden"}})
    end
  end

  defp authorize(current_user_id, current_user_id) do
    # Viewing own history: return all groups the user belongs to
    group_ids =
      Groups.list_user_groups(current_user_id)
      |> Enum.map(& &1.id)

    {:authorized, group_ids}
  end

  defp authorize(current_user_id, target_user_id) do
    {:authorized, Groups.visible_group_ids(current_user_id, target_user_id)}
  end
end
