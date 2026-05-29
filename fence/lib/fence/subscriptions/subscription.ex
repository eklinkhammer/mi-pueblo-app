defmodule Fence.Subscriptions.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_tiers ~w(village_member village_elder village_leader)
  @valid_statuses ~w(active expired cancelled grace_period)
  @valid_stores ~w(app_store play_store)

  schema "subscriptions" do
    belongs_to :user, Fence.Accounts.User

    field :tier, :string, default: "village_member"
    field :status, :string, default: "active"
    field :rc_customer_id, :string
    field :rc_entitlement_id, :string
    field :rc_product_id, :string
    field :store, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :user_id,
      :tier,
      :status,
      :rc_customer_id,
      :rc_entitlement_id,
      :rc_product_id,
      :store,
      :current_period_start,
      :current_period_end,
      :expires_at
    ])
    |> validate_required([:user_id, :tier, :status])
    |> validate_inclusion(:tier, @valid_tiers)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:store, @valid_stores ++ [nil])
    |> unique_constraint(:user_id)
  end
end
