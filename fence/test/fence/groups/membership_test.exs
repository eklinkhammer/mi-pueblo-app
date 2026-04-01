defmodule Fence.Groups.MembershipTest do
  use Fence.DataCase, async: true

  alias Fence.Groups.Membership
  import Fence.Factory

  @valid_attrs %{user_id: Ecto.UUID.generate(), group_id: Ecto.UUID.generate(), role: "member"}

  describe "changeset/2" do
    test "valid attrs" do
      changeset = Membership.changeset(%Membership{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = Membership.changeset(%Membership{}, Map.delete(@valid_attrs, :user_id))
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires group_id" do
      changeset = Membership.changeset(%Membership{}, Map.delete(@valid_attrs, :group_id))
      assert %{group_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates role inclusion" do
      changeset = Membership.changeset(%Membership{}, %{@valid_attrs | role: "owner"})
      assert %{role: ["is invalid"]} = errors_on(changeset)
    end

    test "unique constraint on user_id + group_id" do
      user = create_user()
      group = create_group(user)

      # Admin membership already exists from create_group
      {:error, changeset} =
        %Membership{}
        |> Membership.changeset(%{user_id: user.id, group_id: group.id, role: "member"})
        |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "notification_prefs_changeset/2" do
    test "casts notification preference fields" do
      user = create_user()
      group = create_group(user)
      membership = Fence.Groups.get_membership(user.id, group.id)

      changeset =
        Membership.notification_prefs_changeset(membership, %{
          "silence_all_notifications" => true,
          "silence_home_notifications" => true,
          "notify_household" => false
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :silence_all_notifications) == true
      assert Ecto.Changeset.get_change(changeset, :silence_home_notifications) == true
      assert Ecto.Changeset.get_change(changeset, :notify_household) == false
    end

    test "ignores unrelated fields" do
      changeset =
        Membership.notification_prefs_changeset(%Membership{}, %{
          "role" => "admin",
          "silence_all_notifications" => true
        })

      assert changeset.valid?
      assert is_nil(Ecto.Changeset.get_change(changeset, :role))
    end
  end
end
