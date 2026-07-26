defmodule Fence.Repo.Migrations.CreateDwellAndCategoryWatchTables do
  use Ecto.Migration

  def change do
    # Ephemeral per-user cluster state (at most 1 row per user)
    create table(:active_dwells, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :center_lat, :float, null: false
      add :center_lng, :float, null: false
      add :started_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :point_count, :integer, default: 1
      add :confirmed, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:active_dwells, [:user_id])

    # Confirmed dwells with geocoding results
    create table(:dwell_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_seconds, :integer
      add :center_lat, :float, null: false
      add :center_lng, :float, null: false
      add :point_count, :integer
      add :display_name, :string
      add :category, :string
      add :raw_category, :string
      add :geocoding_status, :string, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create index(:dwell_sessions, [:user_id, :started_at])
    create index(:dwell_sessions, [:user_id, :category])

    # Geocoding cache to avoid re-geocoding the same physical spot
    create table(:geocoding_cache, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :lat_rounded, :float, null: false
      add :lng_rounded, :float, null: false
      add :display_name, :string
      add :osm_class, :string
      add :osm_type, :string
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:geocoding_cache, [:lat_rounded, :lng_rounded])

    # Category watch subscriptions
    create table(:category_watches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :watcher_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :watched_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :category, :string, null: false
      add :active, :boolean, default: true
      add :throttle_seconds, :integer, default: 3600

      timestamps(type: :utc_datetime)
    end

    create unique_index(:category_watches, [:watcher_id, :watched_user_id, :category])
    create index(:category_watches, [:watched_user_id, :category])
  end
end
