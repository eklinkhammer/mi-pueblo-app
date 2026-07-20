defmodule Fence.Repo.Migrations.CreatePendingGeofenceTransitions do
  use Ecto.Migration

  def change do
    create table(:pending_geofence_transitions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :delete_all),
        null: false

      add :event, :string, null: false
      add :first_seen_at, :utc_datetime, null: false
      add :last_confirmed_at, :utc_datetime, null: false
      add :confirmation_count, :integer, default: 1, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pending_geofence_transitions, [:user_id, :geofence_id])
    create index(:pending_geofence_transitions, [:geofence_id])
  end
end
