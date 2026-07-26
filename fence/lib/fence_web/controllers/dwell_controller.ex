defmodule FenceWeb.DwellController do
  use FenceWeb, :controller

  alias Fence.{Dwells, Groups}

  def index(conn, %{"user_id" => user_id}) do
    viewer_id = conn.assigns.current_user.id

    # Check visibility (viewer must be able to see the user, or be the user)
    if viewer_id == user_id or Groups.visible_group_ids(viewer_id, user_id) != [] do
      opts =
        conn.params
        |> Map.take(["limit", "category"])
        |> Enum.reduce([], fn
          {"limit", val}, acc -> [{:limit, String.to_integer(val)} | acc]
          {"category", val}, acc -> [{:category, val} | acc]
        end)

      sessions = Dwells.list_user_dwell_sessions(user_id, opts)
      json(conn, %{dwells: Enum.map(sessions, &dwell_json/1)})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "No visibility to this user"})
    end
  end

  defp dwell_json(session) do
    %{
      id: session.id,
      started_at: session.started_at,
      ended_at: session.ended_at,
      duration_seconds: session.duration_seconds,
      latitude: session.center_lat,
      longitude: session.center_lng,
      display_name: session.display_name,
      category: session.category,
      point_count: session.point_count
    }
  end
end
