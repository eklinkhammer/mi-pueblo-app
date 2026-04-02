defmodule FenceWeb.VisibilityControllerTest do
  use FenceWeb.ConnCase, async: true

  alias Fence.Groups

  import Fence.Factory

  setup %{conn: conn} do
    user = create_user()
    conn = authed_conn(conn, user)
    %{conn: conn, user: user}
  end

  defp setup_group_with_member(admin) do
    member = create_user(%{"display_name" => "Member"})
    group = create_group(admin)
    {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)
    {:ok, _} = Groups.join_by_invite_code(member.id, invite.code)
    {group, member}
  end

  describe "GET /api/v1/groups/:id/visibility" do
    test "lists pending visibility pairs for new joiner", %{conn: conn, user: user} do
      {group, member} = setup_group_with_member(user)

      conn = get(conn, "/api/v1/groups/#{group.id}/visibility")
      assert %{"visibility_pairs" => pairs} = json_response(conn, 200)
      assert length(pairs) == 1

      pair = hd(pairs)
      assert pair["other_user_id"] == member.id
      assert pair["status"] == "pending"
      assert is_nil(pair["granted_by_id"])
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)

      conn = get(conn, "/api/v1/groups/#{group.id}/visibility")
      assert json_response(conn, 403)
    end
  end

  describe "PUT /api/v1/groups/:id/visibility/:user_id" do
    test "grants visibility, returns active status", %{conn: conn, user: user} do
      {group, member} = setup_group_with_member(user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/visibility/#{member.id}", %{"visible" => true})

      assert %{"ok" => true, "status" => "active"} = json_response(conn, 200)
    end

    test "revokes visibility, returns pending status", %{conn: conn, user: user} do
      {group, member} = setup_group_with_member(user)

      # First grant
      {:ok, _} = Groups.grant_visibility(user.id, group.id, member.id)

      conn =
        conn
        |> recycle()
        |> authed_conn(user)
        |> put("/api/v1/groups/#{group.id}/visibility/#{member.id}", %{"visible" => false})

      assert %{"ok" => true, "status" => "pending"} = json_response(conn, 200)
    end

    test "returns 404 for nonexistent pair", %{conn: conn, user: user} do
      group = create_group(user)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/visibility/#{Ecto.UUID.generate()}", %{
          "visible" => true
        })

      assert json_response(conn, 404)
    end

    test "returns 403 for non-member", %{conn: conn} do
      other = create_user()
      group = create_group(other)

      conn =
        put(conn, "/api/v1/groups/#{group.id}/visibility/#{other.id}", %{"visible" => true})

      assert json_response(conn, 403)
    end
  end
end
