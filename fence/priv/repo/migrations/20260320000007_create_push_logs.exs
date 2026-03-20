defmodule Fence.Repo.Migrations.CreatePushLogs do
  use Ecto.Migration

  def change do
    create table(:push_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :triggering_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :geofence_id, references(:geofences, type: :binary_id, on_delete: :nilify_all)
      add :event, :string, null: false
      add :status, :string, null: false, default: "sent"

      timestamps(type: :utc_datetime)
    end

    create index(:push_logs, [:recipient_id])
    create index(:push_logs, [:geofence_id])
    create index(:push_logs, [:inserted_at])
  end
end
