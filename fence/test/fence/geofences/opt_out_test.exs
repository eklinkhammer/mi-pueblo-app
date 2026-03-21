defmodule Fence.Geofences.OptOutTest do
  use Fence.DataCase, async: true

  alias Fence.Geofences.OptOut

  describe "changeset/2" do
    test "valid attrs" do
      changeset =
        OptOut.changeset(%OptOut{}, %{
          user_id: Ecto.UUID.generate(),
          geofence_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = OptOut.changeset(%OptOut{}, %{geofence_id: Ecto.UUID.generate()})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires geofence_id" do
      changeset = OptOut.changeset(%OptOut{}, %{user_id: Ecto.UUID.generate()})
      assert %{geofence_id: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
