defmodule FenceWeb.DashboardLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.Locations

  describe "DashboardLive" do
    test "mounts with group dropdown showing All Users", %{conn: conn} do
      {:ok, _view, html} = live_admin(conn, "/web/dashboard")

      assert html =~ "All Users"
    end

    test "default view shows all users locations", %{conn: conn} do
      user = create_user()
      other_user = create_user(%{"display_name" => "Other Person"})

      {:ok, _loc} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      {:ok, _loc} =
        Locations.report_location(other_user.id, %{
          "latitude" => 40.7128,
          "longitude" => -74.006,
          "accuracy" => 10.0
        })

      {:ok, _view, html} = live_admin(conn, "/web/dashboard")

      assert html =~ user.display_name
      assert html =~ "Other Person"
    end

    test "empty state shows no locations message", %{conn: conn} do
      {:ok, _view, html} = live_admin(conn, "/web/dashboard")

      assert html =~ "No locations yet"
    end
  end

  describe "Admin Actions" do
    test "shows admin actions section with users tab by default", %{conn: conn} do
      user = create_user(%{"display_name" => "Admin Test User"})

      {:ok, _view, html} = live_admin(conn, "/web/dashboard")

      assert html =~ "Admin Actions"
      assert html =~ "Admin Test User"
      assert html =~ user.email
    end

    test "switch to groups tab", %{conn: conn} do
      user = create_user()
      _group = create_group(user, %{"name" => "Test Admin Group"})

      {:ok, view, _html} = live_admin(conn, "/web/dashboard")

      html = view |> element(~s{button[phx-value-tab="groups"]}) |> render_click()

      assert html =~ "Test Admin Group"
    end

    test "switch to geofences tab", %{conn: conn} do
      user = create_user()
      group = create_group(user)
      _geofence = create_geofence(group, user, %{"name" => "Test Admin Geofence"})

      {:ok, view, _html} = live_admin(conn, "/web/dashboard")

      html = view |> element(~s{button[phx-value-tab="geofences"]}) |> render_click()

      assert html =~ "Test Admin Geofence"
    end

    test "delete user removes them from the list", %{conn: conn} do
      user = create_user(%{"display_name" => "Doomed User"})

      {:ok, view, html} = live_admin(conn, "/web/dashboard")
      assert html =~ "Doomed User"

      html =
        view
        |> element(~s{button[phx-click="delete_user"][phx-value-id="#{user.id}"]})
        |> render_click()

      refute html =~ "Doomed User"
    end

    test "delete group removes it from the list", %{conn: conn} do
      user = create_user()
      group = create_group(user, %{"name" => "Doomed Group"})

      {:ok, view, _html} = live_admin(conn, "/web/dashboard")

      # Switch to groups tab
      view |> element(~s{button[phx-value-tab="groups"]}) |> render_click()

      html =
        view
        |> element(~s{button[phx-click="delete_group"][phx-value-id="#{group.id}"]})
        |> render_click()

      refute html =~ "Doomed Group"
    end

    test "delete geofence removes it from the list", %{conn: conn} do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user, %{"name" => "Doomed Geofence"})

      {:ok, view, _html} = live_admin(conn, "/web/dashboard")

      # Switch to geofences tab
      view |> element(~s{button[phx-value-tab="geofences"]}) |> render_click()

      html =
        view
        |> element(~s{button[phx-click="delete_geofence"][phx-value-id="#{geofence.id}"]})
        |> render_click()

      refute html =~ "Doomed Geofence"
    end
  end
end
