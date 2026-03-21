defmodule FenceWeb.PresenceTest do
  use FenceWeb.ChannelCase, async: false

  import Fence.Factory

  alias Fence.Groups
  alias FenceWeb.Presence

  defp add_member_to_group(group, user) do
    {:ok, invite} = Groups.create_invite(group.id, group.created_by_id)
    {:ok, _membership} = Groups.join_by_invite_code(user.id, invite.code)
  end

  defp join_member(group) do
    member = create_user(%{"display_name" => "Member"})
    add_member_to_group(group, member)
    member_token = auth_token(member)
    {:ok, member_socket} = connect(FenceWeb.UserSocket, %{"token" => member_token})
    {:ok, _, member_socket} = subscribe_and_join(member_socket, "group:#{group.id}", %{})
    {member, member_socket}
  end

  setup do
    admin = create_user(%{"display_name" => "Admin"})
    group = create_group(admin)
    token = auth_token(admin)
    {:ok, socket} = connect(FenceWeb.UserSocket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "group:#{group.id}", %{})

    # Drain all messages from the admin joining (presence_state + presence_diff)
    assert_push "presence_state", _payload
    assert_push "presence_diff", %{joins: admin_joins}
    assert Map.has_key?(admin_joins, admin.id)

    %{socket: socket, admin: admin, group: group}
  end

  describe "track/3" do
    test "tracks user presence with expected metadata", %{admin: admin, group: group} do
      presences = Presence.list("group:#{group.id}")

      assert Map.has_key?(presences, admin.id)
      %{metas: [meta]} = Map.get(presences, admin.id)

      assert meta.display_name == "Admin"
      assert is_integer(meta.online_at)
    end
  end

  describe "list/1" do
    test "lists all present users in a group", %{admin: admin, group: group} do
      presences = Presence.list("group:#{group.id}")

      assert map_size(presences) == 1
      assert Map.has_key?(presences, admin.id)
    end

    test "shows multiple users when both join", %{admin: admin, group: group} do
      {member, _member_socket} = join_member(group)

      # Drain the member's join messages
      assert_push "presence_diff", %{joins: joins}
      assert Map.has_key?(joins, member.id)

      presences = Presence.list("group:#{group.id}")

      assert map_size(presences) == 2
      assert Map.has_key?(presences, admin.id)
      assert Map.has_key?(presences, member.id)
    end

    test "returns empty map for group with no connections" do
      other_admin = create_user()
      other_group = create_group(other_admin)

      presences = Presence.list("group:#{other_group.id}")
      assert presences == %{}
    end
  end

  describe "presence_diff" do
    test "broadcasts join diff when a member joins", %{group: group} do
      {member, _member_socket} = join_member(group)

      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      assert Map.has_key?(joins, member.id)
      assert leaves == %{}

      %{metas: [meta]} = Map.get(joins, member.id)
      assert meta.display_name == "Member"
      assert is_integer(meta.online_at)
    end

    test "presence is removed after untrack", %{admin: admin, group: group} do
      {member, member_socket} = join_member(group)

      # Drain the join diff
      assert_push "presence_diff", %{joins: _}

      # Verify both users are present
      presences = Presence.list("group:#{group.id}")
      assert map_size(presences) == 2

      # Untrack the member using the channel PID that tracked it
      :ok = Presence.untrack(member_socket.channel_pid, "group:#{group.id}", member.id)

      # After untracking, only admin should remain
      presences = Presence.list("group:#{group.id}")
      assert map_size(presences) == 1
      assert Map.has_key?(presences, admin.id)
      refute Map.has_key?(presences, member.id)
    end
  end
end
