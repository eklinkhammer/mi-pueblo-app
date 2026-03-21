defmodule FenceWeb.GroupChannelTest do
  use FenceWeb.ChannelCase, async: false

  import Fence.Factory

  setup do
    admin = create_user(%{"display_name" => "Admin"})
    group = create_group(admin)
    token = auth_token(admin)
    {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})
    %{socket: socket, admin: admin, group: group}
  end

  describe "join/3" do
    test "member can join group channel", %{socket: socket, group: group} do
      assert {:ok, _, _socket} = subscribe_and_join(socket, "group:#{group.id}", %{})
    end

    test "non-member cannot join group channel" do
      non_member = create_user()
      other_admin = create_user()
      group = create_group(other_admin)
      token = auth_token(non_member)
      {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})

      assert {:error, %{reason: "unauthorized"}} =
               subscribe_and_join(socket, "group:#{group.id}", %{})
    end

    test "tracks presence after join", %{socket: socket, group: group} do
      {:ok, _, _socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

      # After join, presence_state should be pushed
      assert_push "presence_state", _payload
    end
  end

  describe "handle_in location:update" do
    test "reports location via channel", %{socket: socket, group: group} do
      {:ok, _, socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

      ref =
        push(socket, "location:update", %{
          "latitude" => 37.7749,
          "longitude" => -122.4194,
          "accuracy" => 5.0
        })

      assert_reply ref, :ok
    end
  end
end
