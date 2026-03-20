defmodule Fence.Locations.UserGeofenceState do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_geofence_state" do
    belongs_to :user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    field :entered_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [:user_id, :geofence_id, :entered_at])
    |> validate_required([:user_id, :geofence_id, :entered_at])
    |> unique_constraint([:user_id, :geofence_id])
  end
end
