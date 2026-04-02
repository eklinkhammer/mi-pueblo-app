defmodule FenceWeb.AuthGoogleTest do
  use FenceWeb.ConnCase, async: true

  import Fence.Factory

  describe "POST /api/v1/auth/google" do
    test "creates new user with valid Google token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/google", %{"id_token" => "valid_google_token"})

      assert %{"user" => user, "access_token" => _, "refresh_token" => _} =
               json_response(conn, 200)

      assert user["email"] == "googleuser@example.com"
      assert user["display_name"] == "Google User"
      assert user["id"]
    end

    test "returns tokens for existing Google user", %{conn: conn} do
      # First call creates the user
      post(conn, "/api/v1/auth/google", %{"id_token" => "valid_google_token_existing"})

      # Second call should return the same user
      conn = post(conn, "/api/v1/auth/google", %{"id_token" => "valid_google_token_existing"})

      assert %{"user" => _, "access_token" => _, "refresh_token" => _} =
               json_response(conn, 200)
    end

    test "links Google to existing email/password user", %{conn: conn} do
      user = create_user(%{"email" => "link_me@example.com"})

      conn =
        post(conn, "/api/v1/auth/google", %{"id_token" => "linking_token_link_me@example.com"})

      assert %{"user" => returned_user, "access_token" => _, "refresh_token" => _} =
               json_response(conn, 200)

      assert returned_user["id"] == user.id
      assert returned_user["email"] == "link_me@example.com"
    end

    test "returns 401 for invalid Google token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/google", %{"id_token" => "invalid_token"})

      assert %{"error" => %{"code" => "invalid_google_token"}} = json_response(conn, 401)
    end

    test "returns 401 for unverified email", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/google", %{
          "id_token" => "unverified_email_google_token"
        })

      assert %{"error" => %{"code" => "invalid_google_token"}} = json_response(conn, 401)
    end

    test "returns 400 when id_token is missing", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/google", %{})
      assert %{"error" => %{"code" => "missing_fields"}} = json_response(conn, 400)
    end
  end

  describe "password login with Google-only user" do
    test "returns invalid_credentials instead of crashing", %{conn: conn} do
      # Create a Google-only user (no password)
      post(conn, "/api/v1/auth/google", %{"id_token" => "valid_google_token_nopass"})

      # Try to login with password — should not crash
      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => "googleuser_nopass@example.com",
          "password" => "anypassword"
        })

      assert %{"error" => %{"code" => "invalid_credentials"}} = json_response(conn, 401)
    end
  end
end
