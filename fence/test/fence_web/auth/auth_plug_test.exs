defmodule FenceWeb.AuthPlugTest do
  use FenceWeb.ConnCase, async: true

  alias Fence.Accounts.Token

  import Fence.Factory

  describe "call/2" do
    test "assigns current_user for valid token" do
      user = create_user()

      conn =
        build_conn()
        |> authed_conn(user)
        |> FenceWeb.AuthPlug.call([])

      assert conn.assigns.current_user.id == user.id
      refute conn.halted
    end

    test "returns 401 for missing authorization header" do
      conn =
        build_conn()
        |> FenceWeb.AuthPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 for invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> FenceWeb.AuthPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 for expired token" do
      config = Application.get_env(:fence, Fence.Accounts.Token)
      secret = Joken.Signer.create("HS256", config[:secret_key])

      claims = %{
        "sub" => Ecto.UUID.generate(),
        "type" => "access",
        "exp" => System.os_time(:second) - 3600
      }

      {:ok, token, _} =
        Joken.generate_and_sign(Token.token_config(), claims, secret)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> FenceWeb.AuthPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 for refresh token used as access" do
      user = create_user()
      {:ok, token, _} = Token.generate_refresh_token(user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> FenceWeb.AuthPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end
  end
end
