defmodule FenceWeb.WebIntegrationHelpers do
  @moduledoc """
  Shared helpers for web integration tests that exercise
  the real session-based auth flow (register/login via form POST).
  """

  import Phoenix.ConnTest
  require Phoenix.LiveViewTest

  @endpoint FenceWeb.Endpoint

  @doc """
  Extracts the CSRF token from an HTML response body.
  """
  def extract_csrf_token(body) do
    [_, token] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
    token
  end

  @doc """
  Registers a user via the web form flow:
  GET /web/register → extract CSRF → POST /web/auth/register.
  Returns the conn with session cookies preserved (after recycle).
  """
  def register_via_web(conn, attrs) do
    conn = get(conn, "/web/register")
    csrf_token = extract_csrf_token(conn.resp_body)

    conn
    |> recycle()
    |> post("/web/auth/register", %{
      "email" => attrs[:email] || attrs["email"],
      "display_name" => attrs[:display_name] || attrs["display_name"],
      "password" => attrs[:password] || attrs["password"],
      "_csrf_token" => csrf_token
    })
  end

  @doc """
  Logs in a user via the web form flow:
  GET /web/login → extract CSRF → POST /web/auth/login.
  Returns the conn with session cookies preserved (after recycle).
  """
  def login_via_web(conn, email, password) do
    conn = get(conn, "/web/login")
    csrf_token = extract_csrf_token(conn.resp_body)

    conn
    |> recycle()
    |> post("/web/auth/login", %{
      "email" => email,
      "password" => password,
      "_csrf_token" => csrf_token
    })
  end

  @doc """
  Logs in via web form, recycles the conn to preserve session,
  and mounts a LiveView.
  """
  def live_via_session(conn, email, password, path) do
    login_conn = login_via_web(conn, email, password)

    login_conn
    |> recycle()
    |> Phoenix.LiveViewTest.live(path)
  end

  @doc """
  Registers via web form, recycles the conn to preserve session,
  and mounts a LiveView.
  """
  def live_after_register(conn, attrs, path) do
    reg_conn = register_via_web(conn, attrs)

    reg_conn
    |> recycle()
    |> Phoenix.LiveViewTest.live(path)
  end

  @doc """
  POSTs to logout endpoint. Requires a conn with an active session.
  """
  def logout_via_web(conn) do
    # Need a CSRF token — visit any page first
    page_conn = get(conn, "/web/login")
    csrf_token = extract_csrf_token(page_conn.resp_body)

    page_conn
    |> recycle()
    |> post("/web/auth/logout", %{"_csrf_token" => csrf_token})
  end
end
