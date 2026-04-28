defmodule FenceWeb.GroupControllerTest do
  use FenceWeb.ConnCase, async: true

  alias Fence.Groups.Invite

  import Fence.Factory

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  describe "GET /api/v1/groups" do
    test "lists user groups", %{conn: conn, user: user} do
      create_group(user, %{"name" => "Group A"})
      conn = get(conn, "/api/v1/groups")
      assert %{"groups" => groups} = json_response(conn, 200)
      assert length(groups) == 1
      assert hd(groups)["name"] == "Group A"
    end

    test "returns empty list for new user", %{conn: conn} do
      new_user = create_user()
      conn = conn |> recycle() |> authed_conn(new_user) |> get("/api/v1/groups")
      assert %{"groups" => []} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/groups" do
    test "creates group", %{conn: conn} do
      conn = post(conn, "/api/v1/groups", %{"name" => "New Group"})
      assert %{"group" => group} = json_response(conn, 201)
      assert group["name"] == "New Group"
    end

    test "raises on empty name (insert! in transaction)", %{conn: conn} do
      # create_group uses Repo.insert! inside transaction,
      # so invalid changeset raises Ecto.InvalidChangesetError
      assert_raise Ecto.InvalidChangesetError, fn ->
        post(conn, "/api/v1/groups", %{"name" => ""})
      end
    end
  end

  describe "GET /api/v1/groups/:id" do
    test "shows group for member", %{conn: conn, user: user} do
      group = create_group(user)
      conn = get(conn, "/api/v1/groups/#{group.id}")
      assert %{"group" => g} = json_response(conn, 200)
      assert g["id"] == group.id
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}")
      assert json_response(conn, 403)
    end

    test "returns 404 for missing group", %{conn: conn} do
      conn = get(conn, "/api/v1/groups/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/groups/:id" do
    test "admin can update group", %{conn: conn, user: user} do
      group = create_group(user)
      conn = put(conn, "/api/v1/groups/#{group.id}", %{"name" => "Renamed"})
      assert %{"group" => g} = json_response(conn, 200)
      assert g["name"] == "Renamed"
    end

    test "non-admin member cannot update", %{conn: conn, user: admin} do
      member = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      conn =
        conn
        |> recycle()
        |> authed_conn(member)
        |> put("/api/v1/groups/#{group.id}", %{"name" => "Hacked"})

      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/v1/groups/:id" do
    test "admin can delete group", %{conn: conn, user: user} do
      group = create_group(user)
      conn = delete(conn, "/api/v1/groups/#{group.id}")
      assert response(conn, 204)
    end

    test "non-admin cannot delete", %{conn: conn, user: admin} do
      member = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      conn =
        conn
        |> recycle()
        |> authed_conn(member)
        |> delete("/api/v1/groups/#{group.id}")

      assert json_response(conn, 403)
    end
  end

  describe "POST /api/v1/groups/join" do
    test "joins group with valid invite code", %{conn: conn, user: admin} do
      joiner = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)

      conn =
        conn
        |> recycle()
        |> authed_conn(joiner)
        |> post("/api/v1/groups/join", %{"invite_code" => invite.code})

      assert %{"group" => g} = json_response(conn, 200)
      assert g["id"] == group.id
    end

    test "returns 404 for invalid code", %{conn: conn} do
      conn = post(conn, "/api/v1/groups/join", %{"invite_code" => "BADCODE1"})
      assert json_response(conn, 404)
    end

    test "returns 410 for expired invite", %{conn: conn, user: admin} do
      joiner = create_user()
      group = create_group(admin)

      {:ok, invite} =
        %Invite{}
        |> Invite.changeset(%{
          group_id: group.id,
          created_by_id: admin.id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        })
        |> Fence.Repo.insert()

      conn =
        conn
        |> recycle()
        |> authed_conn(joiner)
        |> post("/api/v1/groups/join", %{"invite_code" => invite.code})

      assert json_response(conn, 410)
    end

    test "returns 409 for already member", %{conn: conn, user: user} do
      group = create_group(user)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, user.id)

      conn = post(conn, "/api/v1/groups/join", %{"invite_code" => invite.code})
      assert json_response(conn, 409)
    end
  end

  describe "GET /api/v1/groups/:id/members" do
    test "lists members for group member", %{conn: conn, user: user} do
      group = create_group(user)
      conn = get(conn, "/api/v1/groups/#{group.id}/members")
      assert %{"members" => members} = json_response(conn, 200)
      assert length(members) == 1
      assert hd(members)["id"] == user.id
      assert hd(members)["role"] == "admin"
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}/members")
      assert json_response(conn, 403)
    end
  end

  describe "DELETE /api/v1/groups/:id/members/:user_id" do
    test "admin can remove member", %{conn: conn, user: admin} do
      member = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      conn = delete(conn, "/api/v1/groups/#{group.id}/members/#{member.id}")
      assert response(conn, 204)
    end

    test "non-admin cannot remove member", %{conn: conn, user: admin} do
      member = create_user()
      other_member = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)
      {:ok, invite2} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(other_member.id, invite2.code)

      conn =
        conn
        |> recycle()
        |> authed_conn(member)
        |> delete("/api/v1/groups/#{group.id}/members/#{other_member.id}")

      assert json_response(conn, 403)
    end
  end

  describe "POST /api/v1/groups/:id/invites" do
    test "admin can create invite", %{conn: conn, user: user} do
      group = create_group(user)
      conn = post(conn, "/api/v1/groups/#{group.id}/invites")
      assert %{"invite" => inv} = json_response(conn, 201)
      assert inv["code"]
      assert inv["expires_at"]
      assert inv["url"] == "https://fence.app/join/#{inv["code"]}"
    end

    test "non-admin cannot create invite", %{conn: conn, user: admin} do
      member = create_user()
      group = create_group(admin)
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)

      conn =
        conn
        |> recycle()
        |> authed_conn(member)
        |> post("/api/v1/groups/#{group.id}/invites")

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/groups/:id/sharing-mode" do
    test "returns sharing mode for member", %{conn: conn, user: user} do
      group = create_group(user)
      conn = get(conn, "/api/v1/groups/#{group.id}/sharing-mode")
      assert %{"sharing_mode" => "live"} = json_response(conn, 200)
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}/sharing-mode")
      assert json_response(conn, 403)
    end
  end

  describe "PUT /api/v1/groups/:id/sharing-mode" do
    test "updates sharing mode to geofences", %{conn: conn, user: user} do
      group = create_group(user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/sharing-mode", %{"sharing_mode" => "geofences"})

      assert %{"sharing_mode" => "geofences"} = json_response(conn, 200)
    end

    test "updates sharing mode back to live", %{conn: conn, user: user} do
      group = create_group(user)
      Fence.Groups.update_sharing_mode(user.id, group.id, "geofences")

      conn =
        put(conn, "/api/v1/groups/#{group.id}/sharing-mode", %{"sharing_mode" => "live"})

      assert %{"sharing_mode" => "live"} = json_response(conn, 200)
    end

    test "rejects invalid sharing mode", %{conn: conn, user: user} do
      group = create_group(user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/sharing-mode", %{"sharing_mode" => "invalid"})

      assert json_response(conn, 422)
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/sharing-mode", %{"sharing_mode" => "geofences"})

      assert json_response(conn, 403)
    end
  end

  describe "GET /api/v1/groups/:id/notification-preferences" do
    test "returns notification preferences for member", %{conn: conn, user: user} do
      group = create_group(user)
      conn = get(conn, "/api/v1/groups/#{group.id}/notification-preferences")
      assert resp = json_response(conn, 200)
      assert resp["silence_all_notifications"] == false
      assert resp["silence_home_notifications"] == false
      assert resp["notify_household"] == true
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)
      conn = get(conn, "/api/v1/groups/#{group.id}/notification-preferences")
      assert json_response(conn, 403)
    end
  end

  describe "PUT /api/v1/groups/:id/notification-preferences" do
    test "updates notification preferences", %{conn: conn, user: user} do
      group = create_group(user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/notification-preferences", %{
          "silence_all_notifications" => true,
          "notify_household" => false
        })

      assert resp = json_response(conn, 200)
      assert resp["silence_all_notifications"] == true
      assert resp["notify_household"] == false
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/notification-preferences", %{
          "silence_all_notifications" => true
        })

      assert json_response(conn, 403)
    end
  end
end
