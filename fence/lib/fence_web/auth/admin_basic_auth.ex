defmodule FenceWeb.AdminBasicAuth do
  @moduledoc """
  Plug that enforces HTTP Basic Auth using admin credentials
  from application config (ADMIN_USER / ADMIN_PASS env vars).

  On success, stores a synthetic admin user map in the session
  so that LiveView on_mount hooks can pick it up.
  """
  import Plug.Conn

  @admin_id "00000000-0000-0000-0000-000000000000"

  def init(opts), do: opts

  def call(conn, _opts) do
    {expected_user, expected_pass} = Application.get_env(:fence, :admin_credentials)

    case Plug.BasicAuth.parse_basic_auth(conn) do
      {user, pass} ->
        user_ok = Plug.Crypto.secure_compare(user, expected_user)
        pass_ok = Plug.Crypto.secure_compare(pass, expected_pass)

        if user_ok and pass_ok do
          admin_user = %{id: @admin_id, name: "Admin", email: "admin@localhost"}

          if get_session(conn, :admin_user) do
            assign(conn, :current_user, admin_user)
          else
            conn
            |> put_session(:admin_user, admin_user)
            |> assign(:current_user, admin_user)
          end
        else
          conn |> Plug.BasicAuth.request_basic_auth() |> halt()
        end

      :error ->
        conn |> Plug.BasicAuth.request_basic_auth() |> halt()
    end
  end
end
