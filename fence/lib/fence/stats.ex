defmodule Fence.Stats do
  import Ecto.Query
  alias Fence.Groups
  alias Fence.Groups.Membership
  alias Fence.Locations.GeofenceEvent
  alias Fence.Geofences.Geofence
  alias Fence.Repo

  def get_user_stats(user_id) do
    # Find memberships where user has a home_geofence_id set
    memberships =
      from(m in Membership,
        where: m.user_id == ^user_id and not is_nil(m.home_geofence_id),
        join: g in assoc(m, :group),
        join: hg in Geofence,
        on: hg.id == m.home_geofence_id,
        select: %{
          group_id: g.id,
          group_name: g.name,
          home_geofence_id: m.home_geofence_id,
          home_geofence_name: hg.name
        }
      )
      |> Repo.all()

    Enum.map(memberships, fn m ->
      home_visit_count = count_entered_events(m.home_geofence_id)

      visible_ids = Groups.visible_user_ids(user_id, m.group_id)

      # Housemates: users with same home geofence AND in the visible set
      housemate_ids = get_housemate_ids(m.group_id, m.home_geofence_id, user_id, visible_ids)

      housemates =
        Enum.map(housemate_ids, fn {hm_id, display_name} ->
          top = top_non_home_geofences(hm_id, m.group_id, m.home_geofence_id, 3)
          %{display_name: display_name, top_geofences: top}
        end)

      your_top = top_non_home_geofences(user_id, m.group_id, m.home_geofence_id, 3)

      %{
        group_id: m.group_id,
        group_name: m.group_name,
        home_geofence_name: m.home_geofence_name,
        home_visit_count: home_visit_count,
        housemates: housemates,
        your_top_geofences: your_top
      }
    end)
  end

  defp count_entered_events(geofence_id) do
    from(e in GeofenceEvent,
      where: e.geofence_id == ^geofence_id and e.event == "entered",
      select: count(e.id)
    )
    |> Repo.one()
  end

  defp get_housemate_ids(group_id, home_geofence_id, user_id, visible_ids) do
    visible_list = MapSet.to_list(visible_ids)

    from(m in Membership,
      where:
        m.group_id == ^group_id and
          m.home_geofence_id == ^home_geofence_id and
          m.user_id != ^user_id and
          m.user_id in ^visible_list,
      join: u in assoc(m, :user),
      select: {m.user_id, u.display_name}
    )
    |> Repo.all()
  end

  defp top_non_home_geofences(target_user_id, group_id, home_geofence_id, limit) do
    from(e in GeofenceEvent,
      where: e.user_id == ^target_user_id and e.event == "entered",
      join: g in Geofence,
      on: g.id == e.geofence_id,
      where: g.group_id == ^group_id and g.id != ^home_geofence_id,
      group_by: [g.id, g.name],
      order_by: [desc: count(e.id)],
      limit: ^limit,
      select: %{geofence_name: g.name, visit_count: count(e.id)}
    )
    |> Repo.all()
  end
end
