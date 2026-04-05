defmodule Fence.Repo.Migrations.AddSharingModeToMemberships do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add :sharing_mode, :string, null: false, default: "live"
    end
  end
end
