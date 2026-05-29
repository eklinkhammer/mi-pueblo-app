defmodule Fence.Locations.GeofenceEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "geofence_events" do
    belongs_to :user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    field :event, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :geofence_id, :event])
    |> validate_required([:user_id, :geofence_id, :event])
    |> validate_inclusion(:event, ["entered", "exited"])
  end
end
