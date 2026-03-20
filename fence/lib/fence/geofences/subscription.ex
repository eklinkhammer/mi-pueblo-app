defmodule Fence.Geofences.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "geofence_subscriptions" do
    field :notify_on_entry, :boolean, default: true
    field :notify_on_exit, :boolean, default: true
    field :blacklisted_user_ids, {:array, :binary_id}, default: []
    field :throttle_seconds, :integer, default: 300

    belongs_to :user, Fence.Accounts.User
    belongs_to :geofence, Fence.Geofences.Geofence

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :geofence_id,
      :notify_on_entry,
      :notify_on_exit,
      :blacklisted_user_ids,
      :throttle_seconds
    ])
    |> validate_required([:user_id, :geofence_id])
    |> validate_number(:throttle_seconds, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :geofence_id])
  end
end
