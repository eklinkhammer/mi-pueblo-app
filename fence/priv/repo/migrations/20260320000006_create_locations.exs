defmodule Fence.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:device_locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :accuracy, :float
      add :altitude, :float
      add :speed, :float
      add :bearing, :float
      add :battery_level, :float

      timestamps(type: :utc_datetime)
    end

    execute(
      "SELECT AddGeometryColumn('device_locations', 'point', 4326, 'POINT', 2)",
      "ALTER TABLE device_locations DROP COLUMN IF EXISTS point"
    )

    create index(:device_locations, [:user_id])
    create index(:device_locations, [:inserted_at])

    execute(
      "CREATE INDEX device_locations_point_gist ON device_locations USING GIST (point)",
      "DROP INDEX IF EXISTS device_locations_point_gist"
    )

    # Tracks which geofences a user is currently inside
    create table(:user_geofence_state, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :delete_all),
        null: false
      add :entered_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_geofence_state, [:user_id, :geofence_id])
    create index(:user_geofence_state, [:geofence_id])
  end
end
