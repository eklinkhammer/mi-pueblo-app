defmodule Fence.Repo.Migrations.CreateVisibilityPairs do
  use Ecto.Migration

  def change do
    create table(:visibility_pairs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :group_id, references(:groups, type: :binary_id, on_delete: :delete_all), null: false
      add :user_a_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :user_b_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :status, :string, default: "pending", null: false
      add :granted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :granted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:visibility_pairs, [:group_id, :user_a_id, :user_b_id])
    create index(:visibility_pairs, [:group_id, :user_a_id])
    create index(:visibility_pairs, [:group_id, :user_b_id])
    create index(:visibility_pairs, [:group_id, :status])
  end
end
