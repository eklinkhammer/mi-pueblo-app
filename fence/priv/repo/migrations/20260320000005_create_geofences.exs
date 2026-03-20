defmodule Fence.Repo.Migrations.CreateGeofences do
  use Ecto.Migration

  def change do
    create table(:geofences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :description, :text
      add :radius_meters, :float, null: false
      add :expires_at, :utc_datetime, null: false
      add :merged_geofence_id, :binary_id

      timestamps(type: :utc_datetime)
    end

    # PostGIS geometry columns
    execute(
      "SELECT AddGeometryColumn('geofences', 'center', 4326, 'POINT', 2)",
      "ALTER TABLE geofences DROP COLUMN IF EXISTS center"
    )

    execute(
      "SELECT AddGeometryColumn('geofences', 'boundary', 4326, 'GEOMETRY', 2)",
      "ALTER TABLE geofences DROP COLUMN IF EXISTS boundary"
    )

    create index(:geofences, [:group_id])
    create index(:geofences, [:expires_at])

    execute(
      "CREATE INDEX geofences_center_gist ON geofences USING GIST (center)",
      "DROP INDEX IF EXISTS geofences_center_gist"
    )

    execute(
      "CREATE INDEX geofences_boundary_gist ON geofences USING GIST (boundary)",
      "DROP INDEX IF EXISTS geofences_boundary_gist"
    )

    # Subscriptions - who gets notified about which geofence
    create table(:geofence_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :delete_all),
        null: false
      add :notify_on_entry, :boolean, default: true
      add :notify_on_exit, :boolean, default: true
      add :blacklisted_user_ids, {:array, :binary_id}, default: []
      add :throttle_seconds, :integer, default: 300

      timestamps(type: :utc_datetime)
    end

    create unique_index(:geofence_subscriptions, [:user_id, :geofence_id])

    # Opt-outs - users who don't want to be tracked for a geofence
    create table(:geofence_opt_outs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:geofence_opt_outs, [:user_id, :geofence_id])

    # Merged geofences
    create table(:merged_geofences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    execute(
      "SELECT AddGeometryColumn('merged_geofences', 'boundary', 4326, 'GEOMETRY', 2)",
      "ALTER TABLE merged_geofences DROP COLUMN IF EXISTS boundary"
    )

    execute(
      "CREATE INDEX merged_geofences_boundary_gist ON merged_geofences USING GIST (boundary)",
      "DROP INDEX IF EXISTS merged_geofences_boundary_gist"
    )

    # Link geofences to their merged parent
    execute(
      "ALTER TABLE geofences ADD CONSTRAINT geofences_merged_geofence_id_fkey FOREIGN KEY (merged_geofence_id) REFERENCES merged_geofences(id) ON DELETE SET NULL",
      "ALTER TABLE geofences DROP CONSTRAINT IF EXISTS geofences_merged_geofence_id_fkey"
    )
  end
end
