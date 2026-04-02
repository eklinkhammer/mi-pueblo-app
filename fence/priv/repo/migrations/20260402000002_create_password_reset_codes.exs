defmodule Fence.Repo.Migrations.CreatePasswordResetCodes do
  use Ecto.Migration

  def change do
    create table(:password_reset_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      add :attempts, :integer, default: 0, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:password_reset_codes, [:user_id])
    create index(:password_reset_codes, [:expires_at])
  end
end
