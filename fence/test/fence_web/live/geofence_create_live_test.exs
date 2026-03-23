defmodule FenceWeb.GeofenceCreateLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.Geofences

  describe "GeofenceCreateLive" do
    setup do
      user = create_user()
      group = create_group(user)
      %{user: user, group: group}
    end

    test "mounts with create form", %{conn: conn, user: user, group: group} do
      {:ok, _view, html} = live_authed(conn, user, "/web/groups/#{group.id}/geofences/new")

      assert html =~ "Create Geofence"
      assert html =~ ~s(name="name")
      assert html =~ ~s(name="radius")
      assert html =~ "Back to map"
    end

    test "map_clicked stores location and shows coordinates", %{
      conn: conn,
      user: user,
      group: group
    } do
      {:ok, view, _html} = live_authed(conn, user, "/web/groups/#{group.id}/geofences/new")

      html = render_hook(view, "map_clicked", %{"lat" => 37.7749, "lng" => -122.4194})

      assert html =~ "37.7749"
      assert html =~ "-122.4194"
    end

    test "create succeeds with valid data", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/groups/#{group.id}/geofences/new")

      render_hook(view, "map_clicked", %{"lat" => 37.7749, "lng" => -122.4194})

      render_change(view, :validate, %{"name" => "Office", "radius" => "300"})

      render_click(view, "create")

      # Should redirect to /web/map
      assert_redirect(view, "/web/map")

      # Verify geofence was created in DB
      geofences = Geofences.list_active_group_geofences(group.id)
      assert length(geofences) == 1
      assert hd(geofences).name == "Office"
    end

    test "create fails with empty name", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/groups/#{group.id}/geofences/new")

      render_hook(view, "map_clicked", %{"lat" => 37.7749, "lng" => -122.4194})

      html = render_click(view, "create")

      assert html =~ "Name is required"
    end

    test "create fails without location", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/groups/#{group.id}/geofences/new")

      render_change(view, :validate, %{"name" => "Test", "radius" => "200"})

      html = render_click(view, "create")

      assert html =~ "Tap the map to select a location"
    end
  end
end
