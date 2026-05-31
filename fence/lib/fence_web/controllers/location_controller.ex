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
      visible_ids = Groups.visible_user_ids(user.id, group_id)
      allowed_ids = MapSet.put(visible_ids, user.id) |> MapSet.to_list()

      locations = Locations.get_group_last_locations(group_id, user.id, allowed_ids)
      presence = Locations.get_group_geofence_presence(group_id, user.id, allowed_ids)

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
              avatar_url: loc.avatar_url,
              latitude: lat,
              longitude: lng,
              accuracy: loc.accuracy,
              speed: loc.speed,
              battery_level: loc.battery_level,
              updated_at: loc.updated_at
            }
          end),
        geofence_presence:
          Enum.map(presence, fn p ->
            {lng, lat} =
              case p.geofence_center do
                %Geo.Point{coordinates: coords} -> coords
                _ -> {nil, nil}
              end

            %{
              user_id: p.user_id,
              display_name: p.display_name,
              avatar_url: p.avatar_url,
              sharing_mode: p.sharing_mode,
              geofence_id: p.geofence_id,
              geofence_name: p.geofence_name,
              geofence_latitude: lat,
              geofence_longitude: lng,
              entered_at: p.entered_at
            }
          end)
      })
    else
      conn |> put_status(:forbidden) |> json(%{error: %{code: "forbidden", message: "Forbidden"}})
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
