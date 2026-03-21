defmodule Fence.Groups.GroupTest do
  use Fence.DataCase, async: true

  alias Fence.Groups.Group

  describe "changeset/2" do
    test "valid attrs" do
      changeset = Group.changeset(%Group{}, %{name: "My Group"})
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Group.changeset(%Group{}, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name max length" do
      changeset = Group.changeset(%Group{}, %{name: String.duplicate("a", 101)})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "accepts name at max length" do
      changeset = Group.changeset(%Group{}, %{name: String.duplicate("a", 100)})
      assert changeset.valid?
    end
  end
end
