defmodule FenceWeb.WebJourneyTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory
  import FenceWeb.WebIntegrationHelpers

  alias Fence.{Geofences, Groups}

  describe "Login → Geofence journey" do
    setup do
      user = create_user(%{"email" => "journey@example.com", "password" => "password123"})
      group = create_group(user, %{"name" => "Journey Group"})
      %{user: user, group: group}
    end

    test "login → navigate to geofence create → fill form → submit → redirected to detail", %{
      conn: conn,
      group: group
    } do
      {:ok, view, _html} =
        live_via_session(
          conn,
          "journey@example.com",
          "password123",
          "/web/groups/#{group.id}/geofences/new"
        )

      render_hook(view, "map_clicked", %{"lat" => 37.7749, "lng" => -122.4194})
      render_change(view, :validate, %{"name" => "New Park", "radius" => "300"})

      render_click(view, "create")

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r|/web/groups/.+/geofences/.+|

      geofences = Geofences.list_active_group_geofences(group.id)
      assert Enum.any?(geofences, &(&1.name == "New Park"))
    end

    test "login → create geofence (factory) → mount detail", %{
      conn: conn,
      user: user,
      group: group
    } do
      geofence = create_geofence(group, user, %{"name" => "Office"})

      login_conn = login_via_web(conn, "journey@example.com", "password123")

      {:ok, _detail_view, detail_html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      assert detail_html =~ "Office"
      assert detail_html =~ "Notify on entry"
    end

    test "create geofence → toggle notifications → toggle opt-out → delete → verify gone", %{
      conn: conn,
      user: user,
      group: group
    } do
      geofence = create_geofence(group, user, %{"name" => "Temp Fence"})

      login_conn = login_via_web(conn, "journey@example.com", "password123")

      {:ok, detail_view, _html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      # Toggle entry notification (auto-subscribe starts with true, so toggle turns it off)
      render_click(detail_view, "toggle_entry")
      sub = Geofences.get_subscription(user.id, geofence.id)
      assert sub.notify_on_entry == false

      # Toggle opt-out
      render_click(detail_view, "toggle_opt_out")
      assert Geofences.opted_out?(user.id, geofence.id)

      # Delete geofence
      render_click(detail_view, "delete")
      assert_redirect(detail_view, "/web/map")
      assert Geofences.get_geofence(geofence.id) == nil
    end
  end

  describe "Full onboarding journey" do
    test "register → create geofence → view detail → toggle notifications", %{conn: conn} do
      # Step 1: Register
      _reg_conn =
        register_via_web(conn, %{
          email: "onboard@example.com",
          display_name: "Onboard User",
          password: "password123"
        })

      user = Fence.Accounts.get_user_by_email("onboard@example.com")
      {:ok, group} = Groups.create_group(user, %{"name" => "Onboard Group"})

      # Step 2: Navigate to geofence create
      login_conn = login_via_web(build_conn(), "onboard@example.com", "password123")

      {:ok, create_view, _html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/new")

      render_hook(create_view, "map_clicked", %{"lat" => 40.7128, "lng" => -74.006})
      render_change(create_view, :validate, %{"name" => "HQ", "radius" => "500"})

      render_click(create_view, "create")

      {path, _flash} = assert_redirect(create_view)
      assert path =~ ~r|/web/groups/.+/geofences/.+|

      # Step 3: View detail
      [geofence] = Geofences.list_active_group_geofences(group.id)

      login_conn2 = login_via_web(build_conn(), "onboard@example.com", "password123")

      {:ok, detail_view, detail_html} =
        login_conn2
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      assert detail_html =~ "HQ"

      # Step 4: Toggle notifications
      render_click(detail_view, "toggle_entry")
      sub = Geofences.get_subscription(user.id, geofence.id)
      assert sub.notify_on_entry == false
    end
  end

  describe "Landing navigation" do
    test "landing page Get Started link leads to register page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(href="/web/register")

      {:ok, _view, reg_html} = live(conn, "/web/register")
      assert reg_html =~ "Create Account"
    end

    test "landing page Sign In link leads to login page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")
      assert html =~ ~s(href="/web/login")

      {:ok, _view, login_html} = live(conn, "/web/login")
      assert login_html =~ "Sign In"
    end
  end
end
