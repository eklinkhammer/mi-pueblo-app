defmodule FenceWeb.AuthControllerTest do
  use FenceWeb.ConnCase, async: true

  import Fence.Factory

  describe "POST /api/v1/auth/register" do
    test "registers user with valid params", %{conn: conn} do
      params = %{
        "email" => unique_email(),
        "password" => "password123",
        "display_name" => "Test User"
      }

      conn = post(conn, "/api/v1/auth/register", params)

      assert %{"user" => user, "access_token" => _, "refresh_token" => _} =
               json_response(conn, 201)

      assert user["email"] == params["email"]
      assert user["display_name"] == params["display_name"]
      assert user["id"]
    end

    test "returns 422 for invalid params", %{conn: conn} do
      params = %{"email" => "bad", "password" => "short", "display_name" => "X"}

      conn = post(conn, "/api/v1/auth/register", params)
      assert %{"errors" => errors} = json_response(conn, 422)
      assert errors["email"] || errors["password"]
    end

    test "returns 400 for missing required fields", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{"email" => "a@b.com"})
      assert %{"error" => %{"code" => "missing_fields"}} = json_response(conn, 400)
    end

    test "returns 422 for duplicate email", %{conn: conn} do
      user = create_user()

      params = %{
        "email" => user.email,
        "password" => "password123",
        "display_name" => "Another"
      }

      conn = post(conn, "/api/v1/auth/register", params)
      assert json_response(conn, 422)["errors"]["email"]
    end
  end

  describe "POST /api/v1/auth/login" do
    test "authenticates with valid credentials", %{conn: conn} do
      user = create_user()

      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => user.email,
          "password" => "password123"
        })

      assert %{"user" => u, "access_token" => _, "refresh_token" => _} = json_response(conn, 200)
      assert u["id"] == user.id
    end

    test "returns 401 for invalid credentials", %{conn: conn} do
      user = create_user()

      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => user.email,
          "password" => "wrongpassword"
        })

      assert %{"error" => %{"code" => "invalid_credentials"}} = json_response(conn, 401)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "refreshes tokens", %{conn: conn} do
      user = create_user()
      {:ok, %{refresh_token: refresh}} = Fence.Accounts.generate_tokens(user)

      conn = post(conn, "/api/v1/auth/refresh", %{"refresh_token" => refresh})
      assert %{"access_token" => _, "refresh_token" => _} = json_response(conn, 200)
    end

    test "returns 401 for invalid refresh token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/refresh", %{"refresh_token" => "invalid"})
      assert %{"error" => %{"code" => "invalid_refresh_token"}} = json_response(conn, 401)
    end
  end

  describe "GET /api/v1/me" do
    test "returns current user", %{conn: conn} do
      user = create_user()
      conn = conn |> authed_conn(user) |> get("/api/v1/me")
      assert %{"user" => u} = json_response(conn, 200)
      assert u["id"] == user.id
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/v1/me")
      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/v1/me" do
    test "updates display name", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put("/api/v1/me", %{"display_name" => "Updated Name"})

      assert %{"user" => u} = json_response(conn, 200)
      assert u["display_name"] == "Updated Name"
    end

    test "returns 422 for invalid update", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> put("/api/v1/me", %{"display_name" => String.duplicate("a", 101)})

      assert json_response(conn, 422)["errors"]
    end
  end

  describe "POST /api/v1/me/device-token" do
    test "registers device token", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> post("/api/v1/me/device-token", %{"token" => "fcm_123", "platform" => "android"})

      assert json_response(conn, 200)["ok"] == true
    end

    test "returns 422 for invalid platform", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> authed_conn(user)
        |> post("/api/v1/me/device-token", %{"token" => "fcm_123", "platform" => "windows"})

      assert json_response(conn, 422)["errors"]
    end
  end
end
