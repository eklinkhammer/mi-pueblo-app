defmodule Fence.Groups.InviteTest do
  use Fence.DataCase, async: true

  alias Fence.Groups.Invite
  import Fence.Factory

  describe "changeset/2" do
    test "requires group_id" do
      changeset = Invite.changeset(%Invite{}, %{})
      assert %{group_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "auto-generates code" do
      user = create_user()
      group = create_group(user)
      changeset = Invite.changeset(%Invite{}, %{group_id: group.id})
      assert changeset.valid?
      assert get_change(changeset, :code)
      assert String.length(get_change(changeset, :code)) == 6
      assert get_change(changeset, :code) =~ ~r/^[A-Z]{6}$/
    end

    test "auto-generates expires_at ~7 days from now" do
      user = create_user()
      group = create_group(user)
      changeset = Invite.changeset(%Invite{}, %{group_id: group.id})
      expires_at = get_change(changeset, :expires_at)
      assert expires_at

      diff = DateTime.diff(expires_at, DateTime.utc_now(), :second)
      # Should be approximately 7 days (within 60 seconds)
      assert_in_delta diff, 7 * 24 * 3600, 60
    end

    test "does not overwrite provided code" do
      changeset = Invite.changeset(%Invite{code: "EXISTING"}, %{group_id: Ecto.UUID.generate()})
      refute get_change(changeset, :code)
    end

    test "does not overwrite provided expires_at" do
      custom_expiry = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

      changeset =
        Invite.changeset(%Invite{}, %{group_id: Ecto.UUID.generate(), expires_at: custom_expiry})

      assert get_change(changeset, :expires_at) == custom_expiry
    end
  end
end
