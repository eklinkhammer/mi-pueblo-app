defmodule FenceWeb.AnonymousJoinTest do
  use FenceWeb.ConnCase, async: true

  import Fence.Factory

  setup do
    owner = create_user()
    group = create_group(owner)
    {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, owner.id)
    %{owner: owner, group: group, invite: invite}
  end

  describe "POST /api/v1/auth/anonymous-join" do
    test "happy path: joins group and returns user + tokens", %{
      conn: conn,
      group: group,
      invite: invite
    } do
      conn =
        post(conn, "/api/v1/auth/anonymous-join", %{
          "invite_code" => invite.code,
          "display_name" => "Anonymous Alice"
        })

      assert %{
               "user" => user,
               "group" => resp_group,
               "access_token" => access_token,
               "refresh_token" => _
             } = json_response(conn, 201)

      assert user["display_name"] == "Anonymous Alice"
      assert user["is_anonymous"] == true
      assert user["email"] == nil
      assert resp_group["id"] == group.id
      assert resp_group["name"] == group.name

      # Verify the token works for authenticated endpoints
      me_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get("/api/v1/me")

      assert %{"user" => me_user} = json_response(me_conn, 200)
      assert me_user["id"] == user["id"]
    end

    test "returns 404 for invalid invite code", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/anonymous-join", %{
          "invite_code" => "INVALID",
          "display_name" => "Test"
        })

      assert %{"error" => %{"code" => "invalid_invite_code"}} = json_response(conn, 404)
    end

    test "returns 410 for expired invite code", %{conn: conn, group: group, owner: owner} do
      # Create an expired invite directly
      expired_at = DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)

      {:ok, expired_invite} =
        %Fence.Groups.Invite{}
        |> Fence.Groups.Invite.changeset(%{group_id: group.id, created_by_id: owner.id})
        |> Ecto.Changeset.put_change(:expires_at, expired_at)
        |> Fence.Repo.insert()

      conn =
        post(conn, "/api/v1/auth/anonymous-join", %{
          "invite_code" => expired_invite.code,
          "display_name" => "Test"
        })

      assert %{"error" => %{"code" => "invite_code_expired"}} = json_response(conn, 410)
    end

    test "returns 400 for missing fields", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/anonymous-join", %{"invite_code" => "ABC"})

      assert %{"error" => %{"code" => "missing_fields"}} = json_response(conn, 400)
    end

    test "returns 422 for invalid display_name", %{conn: conn, invite: invite} do
      conn =
        post(conn, "/api/v1/auth/anonymous-join", %{
          "invite_code" => invite.code,
          "display_name" => ""
        })

      assert %{"errors" => _} = json_response(conn, 422)
    end

    test "creates visibility pairs with existing members", %{
      conn: conn,
      invite: invite,
      group: group,
      owner: owner
    } do
      post(conn, "/api/v1/auth/anonymous-join", %{
        "invite_code" => invite.code,
        "display_name" => "New Member"
      })

      # The owner should have a visibility pair with the new anonymous user
      pairs = Fence.Groups.list_visibility_pairs(owner.id, group.id)
      assert length(pairs) == 1
    end
  end
end
