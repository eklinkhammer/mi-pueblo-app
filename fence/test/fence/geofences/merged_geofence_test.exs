defmodule Fence.Geofences.MergedGeofenceTest do
  use Fence.DataCase, async: true

  alias Fence.Geofences.MergedGeofence

  describe "changeset/2" do
    test "valid attrs" do
      changeset = MergedGeofence.changeset(%MergedGeofence{}, %{group_id: Ecto.UUID.generate()})
      assert changeset.valid?
    end

    test "requires group_id" do
      changeset = MergedGeofence.changeset(%MergedGeofence{}, %{})
      assert %{group_id: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
