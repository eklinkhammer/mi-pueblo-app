defmodule FenceWeb.UserSocketTest do
  use FenceWeb.ChannelCase, async: true

  import Fence.Factory

  describe "connect/3" do
    test "connects with valid access token" do
      user = create_user()
      token = auth_token(user)

      assert {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})
      assert socket.assigns.user_id == user.id
    end

    test "rejects invalid token" do
      assert :error = connect(FenceWeb.UserSocket, %{"token" => "invalid"})
    end

    test "rejects missing token" do
      assert :error = connect(FenceWeb.UserSocket, %{})
    end

    test "returns correct socket id" do
      user = create_user()
      token = auth_token(user)
      {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})
      assert FenceWeb.UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
