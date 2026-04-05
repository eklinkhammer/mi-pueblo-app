defmodule Fence.Repo.Migrations.DropMemberNotificationPreferences do
  use Ecto.Migration

  def up do
    drop table(:member_notification_preferences)
  end

  def down do
    create table(:member_notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :notify, :boolean, default: true, null: false
      add :notify_home, :boolean, default: true, null: false
      add :observer_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :subject_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:member_notification_preferences, [:observer_id, :subject_id, :group_id])
  end
end
