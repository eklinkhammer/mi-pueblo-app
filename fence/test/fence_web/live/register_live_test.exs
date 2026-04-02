defmodule FenceWeb.RegisterLiveTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory
  import FenceWeb.WebIntegrationHelpers

  describe "RegisterLive" do
    test "renders form with email, display_name, and password inputs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/register")

      assert html =~ "Create Account"
      assert html =~ ~s(type="email")
      assert html =~ ~s(name="email")
      assert html =~ ~s(name="display_name")
      assert html =~ ~s(type="password")
    end

    test "form action is /web/auth/register with method POST", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/register")

      assert html =~ ~s(action="/web/auth/register")
      assert html =~ ~s(method="post")
    end

    test "shows link to login page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/web/register")

      assert html =~ "Already have an account?"
      assert html =~ ~s(href="/web/login")
    end
  end

  describe "WebAuthController.register" do
    test "successful registration redirects to /web/map", %{conn: conn} do
      conn =
        register_via_web(conn, %{
          email: "newuser@example.com",
          display_name: "New User",
          password: "password123"
        })

      assert redirected_to(conn) == "/web/map"
    end

    test "successful registration puts share_token in session", %{conn: conn} do
      {:ok, _view, html} =
        live_after_register(
          conn,
          %{
            email: "session@example.com",
            display_name: "Session User",
            password: "password123"
          },
          "/web/map"
        )

      assert html =~ "Map"
    end

    test "duplicate email redirects back with error flash", %{conn: conn} do
      _existing = create_user(%{"email" => "taken@example.com"})

      conn =
        register_via_web(conn, %{
          email: "taken@example.com",
          display_name: "Dup User",
          password: "password123"
        })

      assert redirected_to(conn) == "/web/register"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Registration failed"
    end

    test "short password redirects back with error flash", %{conn: conn} do
      conn =
        register_via_web(conn, %{
          email: "short@example.com",
          display_name: "Short Pass",
          password: "short"
        })

      assert redirected_to(conn) == "/web/register"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Registration failed"
    end
  end
end
