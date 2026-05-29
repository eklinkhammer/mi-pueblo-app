defmodule FenceWeb.WebCrossUserTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory
  import FenceWeb.WebIntegrationHelpers

  alias Fence.{Geofences, Groups, Locations}

  setup do
    user_a =
      create_user(%{
        "email" => "alice@example.com",
        "password" => "password123",
        "display_name" => "Alice"
      })

    user_b =
      create_user(%{
        "email" => "bob@example.com",
        "password" => "password123",
        "display_name" => "Bob"
      })

    group = create_group(user_a, %{"name" => "Family"})

    # Add user_b to the group via invite
    {:ok, invite} = Groups.get_or_create_invite(group.id, user_a.id)
    {:ok, _membership} = Groups.join_by_invite_code(user_b.id, invite.code)

    # Grant mutual visibility
    {:ok, _} = Groups.grant_visibility(user_a.id, group.id, user_b.id)

    %{user_a: user_a, user_b: user_b, group: group}
  end

  describe "Cross-user visibility" do
    test "user A creates geofence → user B sees it on map sidebar", %{
      user_a: user_a,
      group: group
    } do
      _geofence = create_geofence(group, user_a, %{"name" => "Alice's Place"})

      {:ok, view, _html} =
        live_via_session(build_conn(), "bob@example.com", "password123", "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "Alice&#39;s Place"
    end

    test "user A creates geofence → user B can mount its detail page", %{
      user_a: user_a,
      group: group
    } do
      geofence = create_geofence(group, user_a, %{"name" => "School"})

      login_conn = login_via_web(build_conn(), "bob@example.com", "password123")

      {:ok, _view, html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      assert html =~ "School"
      assert html =~ "Notify on entry"
    end

    test "user B toggles opt-out on user A's geofence → only user B is opted out", %{
      user_a: user_a,
      user_b: user_b,
      group: group
    } do
      geofence = create_geofence(group, user_a, %{"name" => "Park"})

      login_conn = login_via_web(build_conn(), "bob@example.com", "password123")

      {:ok, view, _html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "toggle_opt_out")

      assert Geofences.opted_out?(user_b.id, geofence.id)
      refute Geofences.opted_out?(user_a.id, geofence.id)
    end

    test "user B is auto-subscribed and can toggle off entry/exit on user A's geofence", %{
      user_a: user_a,
      user_b: user_b,
      group: group
    } do
      geofence = create_geofence(group, user_a, %{"name" => "Gym"})

      # User B is auto-subscribed when geofence is created (mutual visibility)
      sub = Geofences.get_subscription(user_b.id, geofence.id)
      assert sub.notify_on_entry == true
      assert sub.notify_on_exit == true

      login_conn = login_via_web(build_conn(), "bob@example.com", "password123")

      {:ok, view, _html} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      # Toggling turns off the already-enabled notifications
      render_click(view, "toggle_entry")
      render_click(view, "toggle_exit")

      sub = Geofences.get_subscription(user_b.id, geofence.id)
      assert sub.notify_on_entry == false
      assert sub.notify_on_exit == false
    end

    test "user A reports location → user B sees Alice in Members sidebar", %{
      user_a: user_a,
      group: group
    } do
      {:ok, _loc} =
        Locations.report_location(user_a.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      {:ok, view, _html} =
        live_via_session(build_conn(), "bob@example.com", "password123", "/web/map")

      html = render_change(view, :select_group, %{"group_id" => group.id})

      assert html =~ "Alice"
    end
  end

  describe "Cross-user lifecycle" do
    test "user A creates geofence → user B sees it → user A deletes it → user B no longer sees it",
         %{
           user_a: user_a,
           group: group
         } do
      geofence = create_geofence(group, user_a, %{"name" => "Temporary"})

      # User B sees it
      {:ok, view_b, _html} =
        live_via_session(build_conn(), "bob@example.com", "password123", "/web/map")

      html = render_change(view_b, :select_group, %{"group_id" => group.id})
      assert html =~ "Temporary"

      # User A deletes it
      login_conn_a = login_via_web(build_conn(), "alice@example.com", "password123")

      {:ok, detail_view, _html} =
        login_conn_a
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(detail_view, "delete")
      assert Geofences.get_geofence(geofence.id) == nil

      # User B refreshes — geofence should be gone
      send(view_b.pid, :refresh)
      html = render(view_b)
      refute html =~ "Temporary"
    end

    test "both users report locations → each sees both names in Members sidebar", %{
      user_a: user_a,
      user_b: user_b,
      group: group
    } do
      {:ok, _} =
        Locations.report_location(user_a.id, %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 10.0
        })

      {:ok, _} =
        Locations.report_location(user_b.id, %{
          "latitude" => 37.78,
          "longitude" => -122.42,
          "accuracy" => 10.0
        })

      # User A sees both
      {:ok, view_a, _html} =
        live_via_session(build_conn(), "alice@example.com", "password123", "/web/map")

      html_a = render_change(view_a, :select_group, %{"group_id" => group.id})
      assert html_a =~ "Alice"
      assert html_a =~ "Bob"

      # User B sees both
      {:ok, view_b, _html} =
        live_via_session(build_conn(), "bob@example.com", "password123", "/web/map")

      html_b = render_change(view_b, :select_group, %{"group_id" => group.id})
      assert html_b =~ "Alice"
      assert html_b =~ "Bob"
    end
  end

  describe "Authorization boundary" do
    test "user from different group cannot access geofence detail", %{
      user_a: user_a,
      group: group
    } do
      geofence = create_geofence(group, user_a, %{"name" => "Private"})

      # Create an outsider
      outsider =
        create_user(%{
          "email" => "outsider@example.com",
          "password" => "password123",
          "display_name" => "Outsider"
        })

      _other_group = create_group(outsider, %{"name" => "Other Group"})

      login_conn = login_via_web(build_conn(), "outsider@example.com", "password123")

      # Outsider tries to access geofence with their own group_id — should redirect
      # because the geofence doesn't belong to that group
      [outsider_group] = Groups.list_user_groups(outsider.id)

      {:error, {:live_redirect, %{to: "/web/map"}}} =
        login_conn
        |> recycle()
        |> Phoenix.LiveViewTest.live("/web/groups/#{outsider_group.id}/geofences/#{geofence.id}")
    end
  end
end
