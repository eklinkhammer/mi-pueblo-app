defmodule Fence.Repo.Migrations.CreateShareTokens do
  use Ecto.Migration

  def change do
    create table(:share_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :label, :string
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:share_tokens, [:token])
    create index(:share_tokens, [:user_id])
  end
end
