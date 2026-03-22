defmodule FenceWeb.LoginLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  describe "LoginLive" do
    test "mounts and renders login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/login")

      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Sign In"
      assert html =~ ~s(type="email")
      assert html =~ ~s(type="password")
    end

    test "shows link to registration", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/login")

      assert html =~ "Register"
      assert html =~ ~s(href="/web/register")
    end

    test "form posts to correct endpoint", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/login")

      assert html =~ ~s(action="/web/auth/login")
      assert html =~ ~s(method="post")
    end
  end

  describe "WebAuthController.login" do
    setup do
      user = create_user(%{"email" => "login@example.com", "password" => "password123"})
      %{user: user}
    end

    test "successful login redirects to /web/map", %{conn: conn} do
      # Fetch CSRF token by visiting the login page
      conn = get(conn, "/web/login")
      csrf_token = conn.resp_body |> extract_csrf_token()

      conn =
        conn
        |> recycle()
        |> post("/web/auth/login", %{
          "email" => "login@example.com",
          "password" => "password123",
          "_csrf_token" => csrf_token
        })

      assert redirected_to(conn) == "/web/map"
    end

    test "failed login with wrong password redirects with flash error", %{conn: conn} do
      conn = get(conn, "/web/login")
      csrf_token = conn.resp_body |> extract_csrf_token()

      conn =
        conn
        |> recycle()
        |> post("/web/auth/login", %{
          "email" => "login@example.com",
          "password" => "wrongpassword",
          "_csrf_token" => csrf_token
        })

      assert redirected_to(conn) == "/web/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end

    test "failed login with nonexistent email redirects with flash error", %{conn: conn} do
      conn = get(conn, "/web/login")
      csrf_token = conn.resp_body |> extract_csrf_token()

      conn =
        conn
        |> recycle()
        |> post("/web/auth/login", %{
          "email" => "nobody@example.com",
          "password" => "password123",
          "_csrf_token" => csrf_token
        })

      assert redirected_to(conn) == "/web/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end
  end

  defp extract_csrf_token(body) do
    [_, token] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
    token
  end
end
