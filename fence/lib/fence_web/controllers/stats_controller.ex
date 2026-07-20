defmodule FenceWeb.StatsController do
  use FenceWeb, :controller

  alias Fence.Stats

  def index(conn, _params) do
    user = conn.assigns.current_user

    stats = Stats.get_user_stats(user.id)

    json(conn, %{
      stats:
        Enum.map(stats, fn s ->
          %{
            group_id: s.group_id,
            group_name: s.group_name,
            home_geofence_name: s.home_geofence_name,
            home_latitude: s.home_latitude,
            home_longitude: s.home_longitude,
            home_visit_count: s.home_visit_count,
            housemates:
              Enum.map(s.housemates, fn hm ->
                %{
                  display_name: hm.display_name,
                  current_geofences:
                    Enum.map(hm.current_geofences, fn cg ->
                      %{name: cg.name, latitude: cg.latitude, longitude: cg.longitude}
                    end),
                  top_geofences:
                    Enum.map(hm.top_geofences, fn tg ->
                      %{
                        geofence_id: tg.geofence_id,
                        geofence_name: tg.geofence_name,
                        visit_count: tg.visit_count
                      }
                    end)
                }
              end),
            your_top_geofences:
              Enum.map(s.your_top_geofences, fn tg ->
                %{
                  geofence_id: tg.geofence_id,
                  geofence_name: tg.geofence_name,
                  visit_count: tg.visit_count
                }
              end)
          }
        end)
    })
  end
end
