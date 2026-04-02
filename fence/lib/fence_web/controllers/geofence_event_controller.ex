defmodule FenceWeb.GeofenceEventController do
  use FenceWeb, :controller

  alias Fence.Locations

  def create(conn, params) do
    user = conn.assigns.current_user

    case Locations.process_geofence_event(user.id, params) do
      {:ok, %{verified: verified}} ->
        json(conn, %{ok: true, verified: verified})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "geofence_not_found", message: "Geofence not found"}})

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> json(%{error: %{code: "geofence_expired", message: "Geofence expired"}})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: %{code: "not_group_member", message: "Not a group member"}})

      {:error, :opted_out} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "opted_out", message: "Opted out of this geofence"}})

      {:error, :invalid_action} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{action: ["must be entered or exited"]}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
