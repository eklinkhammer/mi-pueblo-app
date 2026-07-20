defmodule Fence.Locations.PendingGeofenceTransition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pending_geofence_transitions" do
    field :event, :string
    field :first_seen_at, :utc_datetime
    field :last_confirmed_at, :utc_datetime
    field :confirmation_count, :integer, default: 1

    belongs_to :user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    timestamps(type: :utc_datetime)
  end

  def changeset(transition, attrs) do
    transition
    |> cast(attrs, [
      :user_id,
      :geofence_id,
      :event,
      :first_seen_at,
      :last_confirmed_at,
      :confirmation_count
    ])
    |> validate_required([:user_id, :geofence_id, :event, :first_seen_at, :last_confirmed_at])
    |> validate_inclusion(:event, ["entered", "exited"])
    |> unique_constraint([:user_id, :geofence_id])
  end
end
