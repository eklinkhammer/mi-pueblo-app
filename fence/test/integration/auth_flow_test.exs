defmodule Fence.Integration.AuthFlowTest do
  use Fence.IntegrationCase, async: false

  describe "register → use token → refresh → use new token" do
    test "full auth round-trip via API", %{conn: conn} do
      # 1. Register
      {user, access_token, refresh_token} =
        register_via_api(conn, %{"display_name" => "Alice"})

      assert user["display_name"] == "Alice"
      assert is_binary(access_token)
      assert is_binary(refresh_token)

      # 2. Use access token to GET /me
      resp =
        conn
        |> authed_conn_from_token(access_token)
        |> get("/api/v1/me")
        |> json_response(200)

      assert resp["user"]["id"] == user["id"]
      assert resp["user"]["display_name"] == "Alice"

      # 3. Refresh tokens
      refresh_resp =
        conn
        |> post("/api/v1/auth/refresh", %{"refresh_token" => refresh_token})
        |> json_response(200)

      new_access = refresh_resp["access_token"]
      new_refresh = refresh_resp["refresh_token"]
      assert is_binary(new_access)
      assert is_binary(new_refresh)
      assert new_access != access_token

      # 4. Use new access token
      resp2 =
        conn
        |> authed_conn_from_token(new_access)
        |> get("/api/v1/me")
        |> json_response(200)

      assert resp2["user"]["id"] == user["id"]
    end
  end

  describe "login after registration" do
    test "register via context, then login via API", %{conn: conn} do
      email = unique_email()
      _user = create_user(%{"email" => email, "password" => "password123"})

      resp =
        conn
        |> post("/api/v1/auth/login", %{"email" => email, "password" => "password123"})
        |> json_response(200)

      assert resp["user"]["email"] == email
      assert is_binary(resp["access_token"])

      # Verify the token works
      me_resp =
        conn
        |> authed_conn_from_token(resp["access_token"])
        |> get("/api/v1/me")
        |> json_response(200)

      assert me_resp["user"]["email"] == email
    end
  end

  describe "expired token" do
    test "returns 401 for expired access token", %{conn: conn} do
      user = create_user()

      # Generate a token with a past expiration
      signer = Joken.Signer.create("HS256", FenceWeb.Endpoint.config(:secret_key_base))

      claims = %{
        "sub" => user.id,
        "type" => "access",
        "exp" => DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.to_unix()
      }

      {:ok, expired_token, _} = Joken.encode_and_sign(claims, signer)

      conn
      |> authed_conn_from_token(expired_token)
      |> get("/api/v1/me")
      |> json_response(401)
    end
  end
end
