defmodule Fence.Repo.Migrations.AddHomeGeofenceToMemberships do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add :home_geofence_id, references(:geofences, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:memberships, [:home_geofence_id])
  end
end
