defmodule FenceWeb.WebJourneyTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory
  import FenceWeb.WebIntegrationHelpers

  alias Fence.{Geofences, Groups}

  describe "Register → Map → Group creation journey" do
    test "register via web → mount map → sees create group prompt", %{conn: conn} do
      {:ok, _view, html} =
        live_after_register(conn, %{
          email: "fresh@example.com",
          display_name: "Fresh User",
          password: "password123"
        }, "/web/map")

      assert html =~ "Create a group to get started"
    end

    test "register → create group → group appears in dropdown", %{conn: conn} do
      {:ok, view, _html} =
        live_after_register(conn, %{
          email: "grouper@example.com",
          display_name: "Grouper",
          password: "password123"
        }, "/web/map")

      html = render_submit(view, "create_group", %{"name" => "My Family"})

      assert html =~ "My Family"
      assert html =~ "Group &quot;My Family&quot; created!"
    end

    test "create group form has required name input", %{conn: conn} do
      {:ok, _view, html} =
        live_after_register(conn, %{
          email: "emptygroup@example.com",
          display_name: "Empty Grouper",
          password: "password123"
        }, "/web/map")

      assert html =~ "Create a group to get started"
      assert html =~ ~s(name="name")
      assert html =~ "required"
    end

    test "create group → + Geofence link and map visible", %{conn: conn} do
      {:ok, view, _html} =
        live_after_register(conn, %{
          email: "mapuser@example.com",
          display_name: "Map User",
          password: "password123"
        }, "/web/map")

      html = render_submit(view, "create_group", %{"name" => "Test Group"})

      assert html =~ "+ Geofence"
      assert html =~ "id=\"map\""
    end
  end

  describe "Login → Map → Geofence journey" do
    setup do
      user = create_user(%{"email" => "journey@example.com", "password" => "password123"})
      group = create_group(user, %{"name" => "Journey Group"})
      %{user: user, group: group}
    end

    test "login via web → select group → see geofences and + Geofence link", %{
      conn: conn,
      user: user,
      group: group
    } do
      _geofence = create_geofence(group, user, %{"name" => "Park"})

      {:ok, view, _html} = live_via_session(conn, "journey@example.com", "password123", "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "Park"
      assert html =~ "+ Geofence"
    end

    test "login → navigate to geofence create → fill form → submit → redirected to map", %{
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

      assert_redirect(view, "/web/map")

      geofences = Geofences.list_active_group_geofences(group.id)
      assert Enum.any?(geofences, &(&1.name == "New Park"))
    end

    test "login → create geofence (factory) → see in sidebar → mount detail", %{
      conn: conn,
      user: user,
      group: group
    } do
      geofence = create_geofence(group, user, %{"name" => "Office"})

      {:ok, view, _html} = live_via_session(conn, "journey@example.com", "password123", "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})
      assert html =~ "Office"

      # Mount detail page with same session
      login_conn = login_via_web(build_conn(), "journey@example.com", "password123")

      {:ok, _detail_view, detail_html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live(
          "/web/groups/#{group.id}/geofences/#{geofence.id}"
        )

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
        |> Phoenix.LiveViewTest.live(
          "/web/groups/#{group.id}/geofences/#{geofence.id}"
        )

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
    test "register → create group → create geofence → view detail → toggle notifications", %{
      conn: conn
    } do
      # Step 1: Register and mount map
      {:ok, map_view, html} =
        live_after_register(conn, %{
          email: "onboard@example.com",
          display_name: "Onboard User",
          password: "password123"
        }, "/web/map")

      assert html =~ "Create a group to get started"

      # Step 2: Create group
      html = render_submit(map_view, "create_group", %{"name" => "Onboard Group"})
      assert html =~ "Onboard Group"

      # Grab the group from DB
      user = Fence.Accounts.get_user_by_email("onboard@example.com")
      [group] = Groups.list_user_groups(user.id)

      # Step 3: Navigate to geofence create (need new LiveView mount)
      login_conn = login_via_web(build_conn(), "onboard@example.com", "password123")

      {:ok, create_view, _html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/new")

      render_hook(create_view, "map_clicked", %{"lat" => 40.7128, "lng" => -74.006})
      render_change(create_view, :validate, %{"name" => "HQ", "radius" => "500"})

      render_click(create_view, "create")

      assert_redirect(create_view, "/web/map")

      # Step 4: View detail
      [geofence] = Geofences.list_active_group_geofences(group.id)

      login_conn2 = login_via_web(build_conn(), "onboard@example.com", "password123")

      {:ok, detail_view, detail_html} =
        login_conn2
        |> recycle()
        |> Phoenix.LiveViewTest.live(
          "/web/groups/#{group.id}/geofences/#{geofence.id}"
        )

      assert detail_html =~ "HQ"

      # Step 5: Toggle notifications (auto-subscribe starts with true, toggle turns it off)
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

  describe "Session edge cases" do
    test "session persists across multiple LiveView mounts", %{conn: conn} do
      user = create_user(%{"email" => "persist@example.com", "password" => "password123"})
      _group = create_group(user, %{"name" => "Persist Group"})

      login_conn = login_via_web(conn, "persist@example.com", "password123")

      # First mount
      {:ok, _view1, html1} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/map")

      assert html1 =~ "Persist Group"

      # Second mount on same session
      {:ok, _view2, html2} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/map")

      assert html2 =~ "Persist Group"
    end

    test "invalid share token in session redirects to unauthorized", %{conn: conn} do
      # Manually set an invalid share token in the session
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{share_token: "invalid_token_abc"})
        |> get("/web/map")

      # ShareTokenPlug should reject this with 401
      assert conn.status == 401
    end

    test "login as user A then user B → session switches to user B", %{conn: conn} do
      user_a = create_user(%{"email" => "a@example.com", "password" => "password123"})
      user_b = create_user(%{"email" => "b@example.com", "password" => "password123"})
      _group_a = create_group(user_a, %{"name" => "A's Group"})
      _group_b = create_group(user_b, %{"name" => "B's Group"})

      # Login as A
      {:ok, _view, html_a} =
        live_via_session(conn, "a@example.com", "password123", "/web/map")

      assert html_a =~ "A&#39;s Group"

      # Login as B on fresh conn
      {:ok, _view, html_b} =
        live_via_session(build_conn(), "b@example.com", "password123", "/web/map")

      assert html_b =~ "B&#39;s Group"
      refute html_b =~ "A&#39;s Group"
    end

    test "logout clears session → subsequent map mount fails", %{conn: conn} do
      _user = create_user(%{"email" => "logout@example.com", "password" => "password123"})

      login_conn = login_via_web(conn, "logout@example.com", "password123")

      # Logout
      logout_conn =
        login_conn
        |> recycle()
        |> post("/web/auth/logout", %{
          "_csrf_token" => get_csrf_from_session(login_conn)
        })

      assert redirected_to(logout_conn) == "/"

      # Try to mount map — should fail since session is cleared
      result =
        logout_conn
        |> recycle()
        |> get("/web/map")

      assert result.status == 401
    end
  end

  # Helper to get CSRF token from a session-bearing conn
  defp get_csrf_from_session(conn) do
    page_conn =
      conn
      |> recycle()
      |> get("/web/login")

    extract_csrf_token(page_conn.resp_body)
  end
end
