defmodule Fence.Locations.UserGeofenceStateTest do
  use Fence.DataCase, async: true

  alias Fence.Locations.UserGeofenceState

  @valid_attrs %{
    user_id: Ecto.UUID.generate(),
    geofence_id: Ecto.UUID.generate(),
    entered_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }

  describe "changeset/2" do
    test "valid attrs" do
      changeset = UserGeofenceState.changeset(%UserGeofenceState{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = UserGeofenceState.changeset(%UserGeofenceState{}, Map.delete(@valid_attrs, :user_id))
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires geofence_id" do
      changeset = UserGeofenceState.changeset(%UserGeofenceState{}, Map.delete(@valid_attrs, :geofence_id))
      assert %{geofence_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires entered_at" do
      changeset = UserGeofenceState.changeset(%UserGeofenceState{}, Map.delete(@valid_attrs, :entered_at))
      assert %{entered_at: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
