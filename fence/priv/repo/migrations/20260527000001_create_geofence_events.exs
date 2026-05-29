defmodule Fence.Repo.Migrations.CreateGeofenceEvents do
  use Ecto.Migration

  def change do
    create table(:geofence_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :delete_all),
        null: false

      add :event, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:geofence_events, [:user_id, :inserted_at])
    create index(:geofence_events, [:geofence_id])
  end
end
