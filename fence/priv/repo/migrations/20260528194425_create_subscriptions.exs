defmodule Fence.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :tier, :string, null: false, default: "village_member"
      add :status, :string, null: false, default: "active"
      add :rc_customer_id, :string
      add :rc_entitlement_id, :string
      add :rc_product_id, :string
      add :store, :string
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:user_id])
    create index(:subscriptions, [:rc_customer_id])
    create index(:subscriptions, [:status])
    create index(:subscriptions, [:expires_at])
  end
end
