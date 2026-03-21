defmodule Fence.GroupsTest do
  use Fence.DataCase, async: true

  alias Fence.Groups
  import Fence.Factory

  describe "create_group/2" do
    test "creates group and admin membership in transaction" do
      user = create_user()
      assert {:ok, group} = Groups.create_group(user, %{"name" => "My Group"})
      assert group.name == "My Group"
      assert group.created_by_id == user.id

      membership = Groups.get_membership(user.id, group.id)
      assert membership.role == "admin"
    end

    test "rejects invalid attrs" do
      user = create_user()

      assert_raise Ecto.InvalidChangesetError, fn ->
        Groups.create_group(user, %{"name" => ""})
      end
    end
  end

  describe "get_group/1" do
    test "returns group by id" do
      user = create_user()
      group = create_group(user)
      assert Groups.get_group(group.id).id == group.id
    end

    test "returns nil for missing id" do
      assert is_nil(Groups.get_group(Ecto.UUID.generate()))
    end
  end

  describe "update_group/2" do
    test "updates group name" do
      user = create_user()
      group = create_group(user)
      assert {:ok, updated} = Groups.update_group(group, %{"name" => "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_group/1" do
    test "deletes the group" do
      user = create_user()
      group = create_group(user)
      assert {:ok, _} = Groups.delete_group(group)
      assert is_nil(Groups.get_group(group.id))
    end
  end

  describe "list_user_groups/1" do
    test "returns all groups for user" do
      user = create_user()
      g1 = create_group(user, %{"name" => "Group 1"})
      g2 = create_group(user, %{"name" => "Group 2"})

      groups = Groups.list_user_groups(user.id)
      ids = Enum.map(groups, & &1.id) |> MapSet.new()
      assert MapSet.member?(ids, g1.id)
      assert MapSet.member?(ids, g2.id)
    end

    test "returns empty for user with no groups" do
      user = create_user()
      assert Groups.list_user_groups(user.id) == []
    end
  end

  describe "list_members/1" do
    test "returns members with preloaded users" do
      user = create_user()
      group = create_group(user)
      members = Groups.list_members(group.id)
      assert length(members) == 1
      assert hd(members).user.id == user.id
    end
  end

  describe "is_admin?/2 and is_member?/2" do
    test "creator is admin and member" do
      user = create_user()
      group = create_group(user)
      assert Groups.is_admin?(user.id, group.id)
      assert Groups.is_member?(user.id, group.id)
    end

    test "non-member is not admin or member" do
      user = create_user()
      other = create_user()
      group = create_group(user)
      refute Groups.is_admin?(other.id, group.id)
      refute Groups.is_member?(other.id, group.id)
    end
  end

  describe "remove_member/2" do
    test "removes a member" do
      admin = create_user()
      member = create_user()
      group = create_group(admin)

      # Add member via invite
      {:ok, invite} = Groups.create_invite(group.id, admin.id)
      {:ok, _} = Groups.join_by_invite_code(member.id, invite.code)
      assert Groups.is_member?(member.id, group.id)

      assert {:ok, _} = Groups.remove_member(group.id, member.id)
      refute Groups.is_member?(member.id, group.id)
    end

    test "returns error for non-member" do
      user = create_user()
      group = create_group(user)
      assert {:error, :not_found} = Groups.remove_member(group.id, Ecto.UUID.generate())
    end
  end

  describe "create_invite/2" do
    test "creates invite with generated code" do
      user = create_user()
      group = create_group(user)
      assert {:ok, invite} = Groups.create_invite(group.id, user.id)
      assert String.length(invite.code) == 8
      assert invite.expires_at
    end
  end

  describe "join_by_invite_code/2" do
    test "creates membership on valid code" do
      admin = create_user()
      joiner = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.create_invite(group.id, admin.id)

      assert {:ok, membership} = Groups.join_by_invite_code(joiner.id, invite.code)
      assert membership.group.id == group.id
      assert Groups.is_member?(joiner.id, group.id)
    end

    test "member role defaults to member" do
      admin = create_user()
      joiner = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.create_invite(group.id, admin.id)
      {:ok, _} = Groups.join_by_invite_code(joiner.id, invite.code)

      m = Groups.get_membership(joiner.id, group.id)
      assert m.role == "member"
    end

    test "rejects invalid code" do
      user = create_user()
      assert {:error, :invalid_code} = Groups.join_by_invite_code(user.id, "BADCODE1")
    end

    test "rejects expired invite" do
      admin = create_user()
      joiner = create_user()
      group = create_group(admin)

      # Manually insert expired invite
      {:ok, invite} =
        %Fence.Groups.Invite{}
        |> Fence.Groups.Invite.changeset(%{
          group_id: group.id,
          created_by_id: admin.id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        })
        |> Repo.insert()

      assert {:error, :expired} = Groups.join_by_invite_code(joiner.id, invite.code)
    end

    test "rejects already member" do
      admin = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.create_invite(group.id, admin.id)

      # Admin is already a member
      assert {:error, :already_member} = Groups.join_by_invite_code(admin.id, invite.code)
    end
  end
end
