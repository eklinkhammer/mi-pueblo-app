defmodule FenceWeb.LandingLiveTest do
  use FenceWeb.ConnCase, async: false

  describe "LandingLive" do
    test "renders hero content", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Fence"
      assert html =~ "Keep your family close"
    end

    test "renders Get Started link", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(href="/web/register")
      assert html =~ "Get Started"
    end

    test "renders Sign In link", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ ~s(href="/web/login")
      assert html =~ "Sign In"
    end

    test "renders feature cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Location Sharing"
      assert html =~ "Geofence Alerts"
      assert html =~ "Family Groups"
    end
  end
end
