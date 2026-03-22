defmodule FenceWeb.MapLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.Locations

  describe "MapLive" do
    setup do
      user = create_user()
      group = create_group(user, %{"name" => "My Family"})
      %{user: user, group: group}
    end

    test "mounts with group dropdown", %{conn: conn, user: user, group: group} do
      {:ok, _view, html} = live_authed(conn, user, "/web/map")

      assert html =~ "Select a group"
      assert html =~ group.name
    end

    test "shows placeholder when no group selected", %{conn: conn, user: user} do
      {:ok, _view, html} = live_authed(conn, user, "/web/map")

      assert html =~ "Select a group to view the map"
    end

    test "unauthenticated access returns 401", %{conn: conn} do
      conn = get(conn, "/web/map")

      assert conn.status == 401
    end

    test "select_group loads geofence and member data", %{conn: conn, user: user, group: group} do
      _geofence = create_geofence(group, user, %{"name" => "Home Base"})

      {:ok, _loc} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      {:ok, view, _html} = live_authed(conn, user, "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "Home Base"
      assert html =~ user.display_name
    end

    test "empty group shows no-data messages", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "No locations yet"
      assert html =~ "No geofences"
    end

    test "shows + Geofence button after group select", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "+ Geofence"
      assert html =~ "/web/groups/#{group.id}/geofences/new"
    end

    test "refresh picks up new geofence", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/map")
      render_change(view, :select_group, %{"group_id" => group.id})

      # Create geofence after initial load
      create_geofence(group, user, %{"name" => "New Fence"})

      # Simulate the refresh timer
      send(view.pid, :refresh)
      html = render(view)

      assert html =~ "New Fence"
    end
  end
end
