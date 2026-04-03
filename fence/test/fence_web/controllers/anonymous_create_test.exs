defmodule FenceWeb.AnonymousCreateTest do
  use FenceWeb.ConnCase, async: true

  describe "POST /api/v1/auth/anonymous-create" do
    test "happy path: creates group and returns user + tokens", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/anonymous-create", %{
          "group_name" => "Family",
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
      assert resp_group["name"] == "Family"

      # Verify the token works for authenticated endpoints
      me_conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{access_token}")
        |> get("/api/v1/me")

      assert %{"user" => me_user} = json_response(me_conn, 200)
      assert me_user["id"] == user["id"]
    end

    test "returns 400 for missing fields", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/anonymous-create", %{"group_name" => "Family"})

      assert %{"error" => %{"code" => "missing_fields"}} = json_response(conn, 400)
    end

    test "returns 422 for invalid display_name", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/anonymous-create", %{
          "group_name" => "Family",
          "display_name" => ""
        })

      assert %{"errors" => _} = json_response(conn, 422)
    end
  end
end
