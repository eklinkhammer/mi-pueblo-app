defmodule Fence.Repo.Migrations.CreateDeviceTokens do
  use Ecto.Migration

  def change do
    create table(:device_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :text, null: false
      add :platform, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:device_tokens, [:user_id, :platform])
    create index(:device_tokens, [:user_id])
  end
end
