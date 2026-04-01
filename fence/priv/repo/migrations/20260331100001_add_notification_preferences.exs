defmodule Fence.Repo.Migrations.AddNotificationPreferences do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add :silence_all_notifications, :boolean, default: false, null: false
      add :silence_home_notifications, :boolean, default: false, null: false
      add :notify_household, :boolean, default: true, null: false
    end

    create table(:member_notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :observer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :subject_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :notify, :boolean, default: true, null: false
      add :notify_home, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:member_notification_preferences, [:observer_id, :subject_id, :group_id])
    create index(:member_notification_preferences, [:observer_id, :group_id])
  end
end
