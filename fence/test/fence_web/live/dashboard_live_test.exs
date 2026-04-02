defmodule FenceWeb.DashboardLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.Locations

  describe "DashboardLive" do
    setup do
      user = create_user()
      group = create_group(user, %{"name" => "My Family"})
      %{user: user, group: group}
    end

    test "mounts with group dropdown showing All Users", %{conn: conn, user: user, group: group} do
      {:ok, _view, html} = live_authed(conn, user, "/web/dashboard")

      assert html =~ "All Users"
      assert html =~ group.name
    end

    test "default view shows all users locations", %{conn: conn, user: user} do
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

      {:ok, _view, html} = live_authed(conn, user, "/web/dashboard")

      assert html =~ user.display_name
      assert html =~ "Other Person"
    end

    test "selecting a group filters to group members", %{conn: conn, user: user, group: group} do
      other_user = create_user(%{"display_name" => "Outsider"})

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

      {:ok, view, _html} = live_authed(conn, user, "/web/dashboard")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ user.display_name
      refute html =~ "Outsider"
    end

    test "selecting All Users returns to global view", %{conn: conn, user: user, group: group} do
      other_user = create_user(%{"display_name" => "Outsider"})

      {:ok, _loc} =
        Locations.report_location(other_user.id, %{
          "latitude" => 40.7128,
          "longitude" => -74.006,
          "accuracy" => 10.0
        })

      {:ok, view, _html} = live_authed(conn, user, "/web/dashboard")

      # Select group first
      render_change(view, :select_group, %{"group_id" => group.id})
      # Then select All Users
      html = render_change(view, :select_group, %{"group_id" => ""})

      assert html =~ "Outsider"
      assert html =~ "All Users"
    end

    test "sidebar heading shows group name when selected", %{conn: conn, user: user, group: group} do
      {:ok, view, html} = live_authed(conn, user, "/web/dashboard")

      # Default heading
      assert html =~ "All Users"

      # After selecting group
      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "My Family"
    end

    test "refresh respects selected group filter", %{conn: conn, user: user, group: group} do
      {:ok, view, _html} = live_authed(conn, user, "/web/dashboard")
      render_change(view, :select_group, %{"group_id" => group.id})

      # Report location after initial load
      {:ok, _loc} =
        Locations.report_location(user.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      # Simulate refresh timer
      send(view.pid, :refresh)
      html = render(view)

      assert html =~ user.display_name
    end

    test "empty state shows no locations message", %{conn: conn, user: user} do
      {:ok, _view, html} = live_authed(conn, user, "/web/dashboard")

      assert html =~ "No locations yet"
    end
  end
end
