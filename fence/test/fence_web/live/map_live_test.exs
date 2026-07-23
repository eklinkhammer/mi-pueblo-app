defmodule FenceWeb.MapLiveTest do
  use FenceWeb.ConnCase, async: false

  describe "MapLive" do
    test "mounts with group dropdown", %{conn: conn} do
      {:ok, _view, html} = live_admin(conn, "/web/map")

      assert html =~ "All Users"
    end

    test "shows create group prompt when admin has no groups", %{conn: conn} do
      {:ok, _view, html} = live_admin(conn, "/web/map")

      assert html =~ "Create a group to enable geofences"
    end

    test "unauthenticated access returns 401", %{conn: conn} do
      conn = get(conn, "/web/map")

      assert conn.status == 401
    end
  end
end
