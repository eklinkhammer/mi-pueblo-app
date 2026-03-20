defmodule Fence.Geofences.OptOut do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "geofence_opt_outs" do
    belongs_to :user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    timestamps(type: :utc_datetime)
  end

  def changeset(opt_out, attrs) do
    opt_out
    |> cast(attrs, [:user_id, :geofence_id])
    |> validate_required([:user_id, :geofence_id])
    |> unique_constraint([:user_id, :geofence_id])
  end
end
