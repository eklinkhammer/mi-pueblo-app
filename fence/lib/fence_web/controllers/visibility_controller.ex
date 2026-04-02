defmodule FenceWeb.VisibilityController do
  use FenceWeb, :controller

  alias Fence.Groups

  def index(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    if Groups.member?(user.id, group_id) do
      pairs = Groups.list_visibility_pairs(user.id, group_id)

      json(conn, %{
        visibility_pairs:
          Enum.map(pairs, fn p ->
            %{
              id: p.id,
              other_user_id: p.other_user_id,
              other_display_name: p.other_display_name,
              status: p.status,
              granted_by_id: p.granted_by_id,
              granted_at: p.granted_at
            }
          end)
      })
    else
      conn |> put_status(:forbidden) |> json(%{error: %{code: "forbidden", message: "Forbidden"}})
    end
  end

  def update(conn, %{"id" => group_id, "user_id" => other_user_id, "visible" => visible}) do
    user = conn.assigns.current_user

    if Groups.member?(user.id, group_id) do
      result =
        if visible do
          Groups.grant_visibility(user.id, group_id, other_user_id)
        else
          Groups.revoke_visibility(user.id, group_id, other_user_id)
        end

      case result do
        {:ok, pair} ->
          FenceWeb.Endpoint.broadcast("group:#{group_id}", "visibility:changed", %{
            user_a_id: pair.user_a_id,
            user_b_id: pair.user_b_id,
            status: pair.status
          })

          json(conn, %{ok: true, status: pair.status})

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: %{code: "not_found", message: "Visibility pair not found"}})

        {:error, _reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: %{code: "update_failed", message: "Could not update visibility"}})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: %{code: "forbidden", message: "Forbidden"}})
    end
  end
end
