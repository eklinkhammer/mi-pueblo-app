defmodule Fence.Repo.Migrations.SimplifyNotificationPreferences do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add :notify_home_activity, :boolean, default: false, null: false
      remove :silence_all_notifications, :boolean, default: false, null: false
      remove :silence_home_notifications, :boolean, default: false, null: false
    end
  end
end
