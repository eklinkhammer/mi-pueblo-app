defmodule FenceWeb.ShareTokenPlugTest do
  use FenceWeb.ConnCase, async: false

  import Fence.Factory

  alias FenceWeb.ShareTokenPlug

  describe "call/2" do
    test "valid token in query param assigns current_user and stores in session" do
      user = create_user()
      st = create_share_token(user)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:params, %{"token" => st.token})
        |> ShareTokenPlug.call([])

      assert conn.assigns.current_user.id == user.id
      assert get_session(conn, :share_token) == st.token
      refute conn.halted
    end

    test "valid token in session falls back when no query param" do
      user = create_user()
      st = create_share_token(user)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{share_token: st.token})
        |> Map.put(:params, %{})
        |> ShareTokenPlug.call([])

      assert conn.assigns.current_user.id == user.id
      refute conn.halted
    end

    test "invalid token returns 401" do
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:params, %{"token" => "totally-invalid-token"})
        |> ShareTokenPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "expired token returns 401" do
      user = create_user()
      {:ok, st} = Fence.Accounts.create_share_token(user.id, days: -1)

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:params, %{"token" => st.token})
        |> ShareTokenPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "no token at all returns 401" do
      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{})
        |> Map.put(:params, %{})
        |> ShareTokenPlug.call([])

      assert conn.status == 401
      assert conn.halted
    end
  end
end
