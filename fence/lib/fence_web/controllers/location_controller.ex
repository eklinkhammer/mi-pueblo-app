defmodule FenceWeb.LocationController do
  use FenceWeb, :controller

  alias Fence.{Groups, Locations}

  def report(conn, params) do
    user = conn.assigns.current_user

    case Locations.report_location(user.id, params) do
      {:ok, location} ->
        json(conn, %{ok: true, location_id: location.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def group_locations(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    if Groups.member?(user.id, group_id) do
      locations = Locations.get_group_last_locations(group_id)

      json(conn, %{
        locations:
          Enum.map(locations, fn loc ->
            {lng, lat} =
              case loc.point do
                %Geo.Point{coordinates: coords} -> coords
                _ -> {nil, nil}
              end

            %{
              user_id: loc.user_id,
              display_name: loc.display_name,
              latitude: lat,
              longitude: lng,
              accuracy: loc.accuracy,
              speed: loc.speed,
              battery_level: loc.battery_level,
              updated_at: loc.updated_at
            }
          end)
      })
    else
      conn |> put_status(:forbidden) |> json(%{error: "Forbidden"})
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
