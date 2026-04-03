defmodule Fence.Repo.Migrations.AddAnonymousUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_anonymous, :boolean, default: false, null: false
    end

    # Make email nullable for anonymous users
    execute "ALTER TABLE users ALTER COLUMN email DROP NOT NULL",
            "ALTER TABLE users ALTER COLUMN email SET NOT NULL"

    # Replace the unique index with a partial one (only non-null emails)
    drop_if_exists unique_index(:users, [:email])
    create unique_index(:users, [:email], where: "email IS NOT NULL", name: :users_email_index)
  end
end
