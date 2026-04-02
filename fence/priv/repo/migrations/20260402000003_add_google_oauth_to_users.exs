defmodule Fence.Repo.Migrations.AddGoogleOauthToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_id, :string
      modify :password_hash, :string, null: true, from: {:string, null: false}
    end

    create unique_index(:users, [:google_id], where: "google_id IS NOT NULL")
  end
end
