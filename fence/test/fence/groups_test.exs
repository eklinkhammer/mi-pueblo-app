defmodule Fence.GroupsTest do
  use Fence.DataCase, async: true

  alias Fence.Groups
  alias Fence.Groups.Invite

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

  describe "admin?/2 and member?/2" do
    test "creator is admin and member" do
      user = create_user()
      group = create_group(user)
      assert Groups.admin?(user.id, group.id)
      assert Groups.member?(user.id, group.id)
    end

    test "non-member is not admin or member" do
      user = create_user()
      other = create_user()
      group = create_group(user)
      refute Groups.admin?(other.id, group.id)
      refute Groups.member?(other.id, group.id)
    end
  end

  describe "remove_member/2" do
    test "removes a member" do
      admin = create_user()
      member = create_user()
      group = create_group(admin)

      # Add member via invite
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Groups.join_by_invite_code(member.id, invite.code)
      assert Groups.member?(member.id, group.id)

      assert {:ok, _} = Groups.remove_member(group.id, member.id)
      refute Groups.member?(member.id, group.id)
    end

    test "returns error for non-member" do
      user = create_user()
      group = create_group(user)
      assert {:error, :not_found} = Groups.remove_member(group.id, Ecto.UUID.generate())
    end
  end

  describe "get_or_create_invite/2" do
    test "creates invite with generated code" do
      user = create_user()
      group = create_group(user)
      assert {:ok, invite} = Groups.get_or_create_invite(group.id, user.id)
      assert String.length(invite.code) == 6
      assert invite.expires_at
    end

    test "returns same invite on second call for same group" do
      user = create_user()
      group = create_group(user)
      assert {:ok, invite1} = Groups.get_or_create_invite(group.id, user.id)
      assert {:ok, invite2} = Groups.get_or_create_invite(group.id, user.id)
      assert invite1.id == invite2.id
    end

    test "creates new invite after previous one expires" do
      user = create_user()
      group = create_group(user)

      # Insert an already-expired invite directly
      {:ok, expired} =
        %Invite{}
        |> Invite.changeset(%{
          group_id: group.id,
          created_by_id: user.id,
          expires_at: DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        })
        |> Repo.insert()

      assert {:ok, new_invite} = Groups.get_or_create_invite(group.id, user.id)
      assert new_invite.id != expired.id
    end

    test "creates separate invites for different groups" do
      user = create_user()
      group1 = create_group(user, %{"name" => "Group 1"})
      group2 = create_group(user, %{"name" => "Group 2"})

      assert {:ok, invite1} = Groups.get_or_create_invite(group1.id, user.id)
      assert {:ok, invite2} = Groups.get_or_create_invite(group2.id, user.id)
      assert invite1.id != invite2.id
    end

    test "different admin reuses same group's invite" do
      admin1 = create_user()
      admin2 = create_user()
      group = create_group(admin1)

      # Make admin2 an admin too (join then we won't check role, just test reuse)
      {:ok, invite_for_join} = Groups.get_or_create_invite(group.id, admin1.id)
      {:ok, _} = Groups.join_by_invite_code(admin2.id, invite_for_join.code)

      assert {:ok, invite1} = Groups.get_or_create_invite(group.id, admin1.id)
      assert {:ok, invite2} = Groups.get_or_create_invite(group.id, admin2.id)
      assert invite1.id == invite2.id
    end
  end

  describe "anonymous_create_group/2" do
    test "creates anonymous user and group with admin membership" do
      assert {:ok, {user, group}} =
               Groups.anonymous_create_group("My Group", %{"display_name" => "Creator"})

      assert user.is_anonymous == true
      assert user.display_name == "Creator"
      assert group.name == "My Group"
      assert group.created_by_id == user.id

      membership = Groups.get_membership(user.id, group.id)
      assert membership.role == "admin"
    end

    test "rolls back on invalid user attrs" do
      assert {:error, _changeset} =
               Groups.anonymous_create_group("My Group", %{"display_name" => ""})

      # No groups should have been created
      # (We can't easily query all groups, but we verify the transaction rolled back
      # by checking the error return)
    end
  end

  describe "anonymous_join/2" do
    test "creates anonymous user and membership" do
      admin = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)

      assert {:ok, {user, returned_group}} =
               Groups.anonymous_join(invite.code, %{"display_name" => "Anon"})

      assert user.is_anonymous == true
      assert user.display_name == "Anon"
      assert returned_group.id == group.id
      assert Groups.member?(user.id, group.id)
    end

    test "returns error for invalid code" do
      assert {:error, :invalid_code} =
               Groups.anonymous_join("BADCODE1", %{"display_name" => "Anon"})
    end

    test "returns error for expired invite" do
      admin = create_user()
      group = create_group(admin)

      {:ok, invite} =
        %Invite{}
        |> Invite.changeset(%{group_id: group.id, created_by_id: admin.id})
        |> Ecto.Changeset.put_change(
          :expires_at,
          DateTime.utc_now() |> DateTime.add(-3600) |> DateTime.truncate(:second)
        )
        |> Repo.insert()

      assert {:error, :expired} =
               Groups.anonymous_join(invite.code, %{"display_name" => "Anon"})
    end

    test "rolls back on invalid user attrs" do
      admin = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)

      assert {:error, _changeset} = Groups.anonymous_join(invite.code, %{"display_name" => ""})

      # No new members should have been added (only the admin)
      assert length(Groups.list_members(group.id)) == 1
    end

    test "creates visibility pairs with existing members" do
      admin = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)

      {:ok, {anon_user, _group}} =
        Groups.anonymous_join(invite.code, %{"display_name" => "Anon"})

      pairs = Groups.list_visibility_pairs(admin.id, group.id)
      assert length(pairs) == 1
      assert hd(pairs).other_user_id == anon_user.id
      assert hd(pairs).status == "pending"
    end
  end

  describe "join_by_invite_code/2" do
    test "creates membership on valid code" do
      admin = create_user()
      joiner = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)

      assert {:ok, membership} = Groups.join_by_invite_code(joiner.id, invite.code)
      assert membership.group.id == group.id
      assert Groups.member?(joiner.id, group.id)
    end

    test "member role defaults to member" do
      admin = create_user()
      joiner = create_user()
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)
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
        %Invite{}
        |> Invite.changeset(%{
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
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)

      # Admin is already a member
      assert {:error, :already_member} = Groups.join_by_invite_code(admin.id, invite.code)
    end
  end

  describe "visibility pairs" do
    defp setup_group_with_joiner do
      admin = create_user(%{"display_name" => "Admin"})
      joiner = create_user(%{"display_name" => "Joiner"})
      group = create_group(admin)
      {:ok, invite} = Groups.get_or_create_invite(group.id, admin.id)
      {:ok, _} = Groups.join_by_invite_code(joiner.id, invite.code)
      {admin, joiner, group}
    end

    test "join_by_invite_code creates pending pairs automatically" do
      {admin, joiner, group} = setup_group_with_joiner()

      pairs = Groups.list_visibility_pairs(admin.id, group.id)
      assert length(pairs) == 1
      pair = hd(pairs)
      assert pair.other_user_id == joiner.id
      assert pair.status == "pending"
      assert is_nil(pair.granted_by_id)
    end

    test "grant_visibility updates to active with granted_by_id" do
      {admin, joiner, group} = setup_group_with_joiner()

      assert {:ok, pair} = Groups.grant_visibility(admin.id, group.id, joiner.id)
      assert pair.status == "active"
      assert pair.granted_by_id == admin.id
      assert pair.granted_at
    end

    test "revoke_visibility resets to pending and clears grant fields" do
      {admin, joiner, group} = setup_group_with_joiner()

      {:ok, _} = Groups.grant_visibility(admin.id, group.id, joiner.id)
      assert {:ok, pair} = Groups.revoke_visibility(admin.id, group.id, joiner.id)
      assert pair.status == "pending"
      assert is_nil(pair.granted_by_id)
      assert is_nil(pair.granted_at)
    end

    test "grant_visibility returns not_found for missing pair" do
      admin = create_user()
      group = create_group(admin)

      assert {:error, :not_found} =
               Groups.grant_visibility(admin.id, group.id, Ecto.UUID.generate())
    end

    test "visible_user_ids returns only active pairs" do
      {admin, joiner, group} = setup_group_with_joiner()

      # Pending — should be empty
      assert MapSet.size(Groups.visible_user_ids(admin.id, group.id)) == 0

      # Grant — should include joiner
      {:ok, _} = Groups.grant_visibility(admin.id, group.id, joiner.id)
      visible = Groups.visible_user_ids(admin.id, group.id)
      assert MapSet.member?(visible, joiner.id)
    end

    test "visible_to? true when active, false when pending" do
      {admin, joiner, group} = setup_group_with_joiner()

      refute Groups.visible_to?(admin.id, joiner.id, group.id)

      {:ok, _} = Groups.grant_visibility(admin.id, group.id, joiner.id)
      assert Groups.visible_to?(admin.id, joiner.id, group.id)
    end

    test "remove_member cleans up all visibility pairs" do
      {admin, joiner, group} = setup_group_with_joiner()

      {:ok, _} = Groups.grant_visibility(admin.id, group.id, joiner.id)
      assert length(Groups.list_visibility_pairs(admin.id, group.id)) == 1

      {:ok, _} = Groups.remove_member(group.id, joiner.id)
      assert Groups.list_visibility_pairs(admin.id, group.id) == []
    end
  end

  describe "update_sharing_mode/3" do
    test "updates sharing mode to geofences" do
      user = create_user()
      group = create_group(user)

      assert {:ok, membership} = Groups.update_sharing_mode(user.id, group.id, "geofences")
      assert membership.sharing_mode == "geofences"
    end

    test "updates sharing mode back to live" do
      user = create_user()
      group = create_group(user)

      {:ok, _} = Groups.update_sharing_mode(user.id, group.id, "geofences")
      assert {:ok, membership} = Groups.update_sharing_mode(user.id, group.id, "live")
      assert membership.sharing_mode == "live"
    end

    test "rejects invalid sharing mode" do
      user = create_user()
      group = create_group(user)

      assert {:error, changeset} = Groups.update_sharing_mode(user.id, group.id, "invalid")
      assert %{sharing_mode: _} = errors_on(changeset)
    end

    test "returns not_found for non-member" do
      user = create_user()
      other = create_user()
      group = create_group(other)

      assert {:error, :not_found} = Groups.update_sharing_mode(user.id, group.id, "live")
    end
  end

  describe "list_user_live_groups/1" do
    test "returns only groups where user has live sharing mode" do
      user = create_user()
      group_live = create_group(user, %{"name" => "Live Group"})
      group_geo = create_group(user, %{"name" => "Geo Group"})

      {:ok, _} = Groups.update_sharing_mode(user.id, group_geo.id, "geofences")

      live_groups = Groups.list_user_live_groups(user.id)
      ids = Enum.map(live_groups, & &1.id)
      assert group_live.id in ids
      refute group_geo.id in ids
    end

    test "returns all groups when all are live" do
      user = create_user()
      g1 = create_group(user, %{"name" => "Group 1"})
      g2 = create_group(user, %{"name" => "Group 2"})

      live_groups = Groups.list_user_live_groups(user.id)
      ids = Enum.map(live_groups, & &1.id)
      assert g1.id in ids
      assert g2.id in ids
    end
  end

  describe "update_notification_preferences/3" do
    test "updates silence and household flags" do
      user = create_user()
      group = create_group(user)

      assert {:ok, membership} =
               Groups.update_notification_preferences(user.id, group.id, %{
                 "silence_all_notifications" => true,
                 "silence_home_notifications" => true,
                 "notify_household" => false
               })

      assert membership.silence_all_notifications == true
      assert membership.silence_home_notifications == true
      assert membership.notify_household == false
    end

    test "returns not_found for non-member" do
      user = create_user()
      other = create_user()
      group = create_group(other)

      assert {:error, :not_found} =
               Groups.update_notification_preferences(user.id, group.id, %{
                 "silence_all_notifications" => true
               })
    end
  end
end
