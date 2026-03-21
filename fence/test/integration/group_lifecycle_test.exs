defmodule Fence.Integration.GroupLifecycleTest do
  use Fence.IntegrationCase, async: false

  describe "create → invite → join → verify members" do
    test "two users join the same group via invite code", %{conn: conn} do
      # User A registers and creates a group
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a
        |> post("/api/v1/groups", %{"name" => "Family"})
        |> json_response(201)

      group_id = group_resp["group"]["id"]
      assert group_resp["group"]["name"] == "Family"

      # A creates an invite
      invite_resp =
        conn_a
        |> post("/api/v1/groups/#{group_id}/invites")
        |> json_response(201)

      invite_code = invite_resp["invite"]["code"]
      assert is_binary(invite_code)

      # User B registers and joins via invite code
      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_b = authed_conn_from_token(conn, token_b)

      join_resp =
        conn_b
        |> post("/api/v1/groups/join", %{"invite_code" => invite_code})
        |> json_response(200)

      assert join_resp["group"]["id"] == group_id

      # Both see 2 members
      members_a =
        conn_a
        |> get("/api/v1/groups/#{group_id}/members")
        |> json_response(200)

      assert length(members_a["members"]) == 2
      roles = Enum.map(members_a["members"], & &1["role"]) |> Enum.sort()
      assert roles == ["admin", "member"]

      members_b =
        conn_b
        |> get("/api/v1/groups/#{group_id}/members")
        |> json_response(200)

      assert length(members_b["members"]) == 2
    end
  end

  describe "non-admin restrictions" do
    test "member cannot update group, delete group, or create invites", %{conn: conn} do
      # Setup: A creates group, B joins
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      conn_a = authed_conn_from_token(conn, token_a)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Family"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      {_user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_b = authed_conn_from_token(conn, token_b)

      conn_b |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})

      # B tries admin-only actions
      conn_b
      |> put("/api/v1/groups/#{group_id}", %{"name" => "Hacked"})
      |> json_response(403)

      conn_b
      |> delete("/api/v1/groups/#{group_id}")
      |> json_response(403)

      conn_b
      |> post("/api/v1/groups/#{group_id}/invites")
      |> json_response(403)
    end
  end

  describe "admin removes member" do
    test "removed member loses access", %{conn: conn} do
      # Setup: A creates group, B joins
      {_user_a, token_a, _} = register_via_api(conn, %{"display_name" => "Alice"})
      {user_b, token_b, _} = register_via_api(conn, %{"display_name" => "Bob"})
      conn_a = authed_conn_from_token(conn, token_a)
      conn_b = authed_conn_from_token(conn, token_b)

      group_resp =
        conn_a |> post("/api/v1/groups", %{"name" => "Family"}) |> json_response(201)

      group_id = group_resp["group"]["id"]

      invite_resp =
        conn_a |> post("/api/v1/groups/#{group_id}/invites") |> json_response(201)

      conn_b
      |> post("/api/v1/groups/join", %{"invite_code" => invite_resp["invite"]["code"]})
      |> json_response(200)

      # A removes B
      conn_a
      |> delete("/api/v1/groups/#{group_id}/members/#{user_b["id"]}")
      |> response(204)

      # B can no longer see the group
      conn_b
      |> get("/api/v1/groups/#{group_id}")
      |> json_response(403)

      # A sees only 1 member
      members =
        conn_a
        |> get("/api/v1/groups/#{group_id}/members")
        |> json_response(200)

      assert length(members["members"]) == 1
    end
  end
end
