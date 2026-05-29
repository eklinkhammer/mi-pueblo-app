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

  describe "handle_in visibility:share" do
    setup %{admin: admin, group: group} do
      member = create_user(%{"display_name" => "Member"})
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)
      %{member: member}
    end

    test "broadcasts visibility:changed with active status", %{
      socket: socket,
      admin: admin,
      group: group,
      member: member
    } do
      {:ok, _, socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

      ref = push(socket, "visibility:share", %{"user_id" => member.id})
      assert_reply ref, :ok

      {a, b} = if admin.id < member.id, do: {admin.id, member.id}, else: {member.id, admin.id}

      assert_broadcast "visibility:changed", %{
        user_a_id: ^a,
        user_b_id: ^b,
        status: "active"
      }
    end

    test "returns error for invalid pair", %{socket: socket, group: group} do
      {:ok, _, socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

      ref = push(socket, "visibility:share", %{"user_id" => Ecto.UUID.generate()})
      assert_reply ref, :error, %{reason: "not_found"}
    end
  end

  describe "handle_in visibility:revoke" do
    setup %{admin: admin, group: group} do
      member = create_user(%{"display_name" => "Member"})
      {:ok, invite} = Fence.Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Fence.Groups.join_by_invite_code(member.id, invite.code)
      # Grant first so we can revoke
      {:ok, _} = Fence.Groups.share_visibility(admin.id, group.id, member.id)
      %{member: member}
    end

    test "broadcasts visibility:changed with pending status", %{
      socket: socket,
      admin: admin,
      group: group,
      member: member
    } do
      {:ok, _, socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

      ref = push(socket, "visibility:revoke", %{"user_id" => member.id})
      assert_reply ref, :ok

      {a, b} = if admin.id < member.id, do: {admin.id, member.id}, else: {member.id, admin.id}

      assert_broadcast "visibility:changed", %{
        user_a_id: ^a,
        user_b_id: ^b,
        status: "pending"
      }
    end
  end
end
