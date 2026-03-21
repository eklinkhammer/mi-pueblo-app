defmodule FenceWeb.ShareTokenPlug do
  @moduledoc """
  Plug that authenticates web requests via share token.

  Checks for a `token` query param first, then falls back to session.
  On success, stores the token in the session so subsequent navigations
  don't need the token in the URL.
  """
  import Plug.Conn
  alias Fence.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    token = conn.params["token"] || get_session(conn, :share_token)

    case token && Accounts.get_user_by_share_token(token) do
      %Accounts.User{} = user ->
        conn
        |> put_session(:share_token, token)
        |> assign(:current_user, user)

      _ ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(401, "Invalid or expired share token")
        |> halt()
    end
  end
end
