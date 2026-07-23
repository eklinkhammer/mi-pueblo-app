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
end
