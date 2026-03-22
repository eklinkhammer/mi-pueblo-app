defmodule FenceWeb.GeofenceDetailLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias Fence.Geofences

  describe "GeofenceDetailLive" do
    setup do
      user = create_user()
      group = create_group(user)
      geofence = create_geofence(group, user, %{"name" => "Home"})
      %{user: user, group: group, geofence: geofence}
    end

    test "mounts with geofence details", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      {:ok, _view, html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      assert html =~ "Home"
      assert html =~ "meters"
      assert html =~ "Notify on entry"
      assert html =~ "Notify on exit"
    end

    test "not-found geofence redirects to map", %{conn: conn, user: user, group: group} do
      fake_id = Ecto.UUID.generate()

      assert {:error, {:live_redirect, %{to: "/web/map"}}} =
               live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{fake_id}")
    end

    test "group_id mismatch redirects to map", %{conn: conn, user: user, geofence: geofence} do
      other_user = create_user()
      other_group = create_group(other_user)

      assert {:error, {:live_redirect, %{to: "/web/map"}}} =
               live_authed(conn, user, "/web/groups/#{other_group.id}/geofences/#{geofence.id}")
    end

    test "toggle_entry updates subscription in DB", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      {:ok, view, _html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "toggle_entry")

      sub = Geofences.get_subscription(user.id, geofence.id)
      assert sub.notify_on_entry == true
    end

    test "toggle_exit updates subscription in DB", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      {:ok, view, _html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "toggle_exit")

      sub = Geofences.get_subscription(user.id, geofence.id)
      assert sub.notify_on_exit == true
    end

    test "toggle_opt_out on creates opt-out in DB", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      {:ok, view, _html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "toggle_opt_out")

      assert Geofences.opted_out?(user.id, geofence.id)
    end

    test "toggle_opt_out off removes opt-out from DB", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      # Create opt-out first
      Geofences.create_opt_out(user.id, geofence.id)

      {:ok, view, _html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "toggle_opt_out")

      refute Geofences.opted_out?(user.id, geofence.id)
    end

    test "delete removes geofence and redirects", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      {:ok, view, _html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      render_click(view, "delete")

      assert_redirect(view, "/web/map")
      assert Geofences.get_geofence(geofence.id) == nil
    end

    test "mounts with existing subscription showing checked state", %{
      conn: conn,
      user: user,
      group: group,
      geofence: geofence
    } do
      # Pre-create subscription
      Geofences.upsert_subscription(%{
        user_id: user.id,
        geofence_id: geofence.id,
        notify_on_entry: true,
        notify_on_exit: true
      })

      {:ok, _view, html} =
        live_authed(conn, user, "/web/groups/#{group.id}/geofences/#{geofence.id}")

      # Both checkboxes should be checked
      assert html =~ ~s(checked)
      assert html =~ "Notify on entry"
      assert html =~ "Notify on exit"
    end
  end
end
