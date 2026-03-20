defmodule Fence.Repo.Migrations.CreateGroups do
  use Ecto.Migration

  def change do
    create table(:groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:memberships, [:user_id, :group_id])
    create index(:memberships, [:group_id])

    create table(:invites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :code, :string, null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invites, [:code])
    create index(:invites, [:group_id])
  end
end
