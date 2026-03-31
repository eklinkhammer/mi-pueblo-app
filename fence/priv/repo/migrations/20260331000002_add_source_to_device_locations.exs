defmodule Fence.Repo.Migrations.AddSourceToDeviceLocations do
  use Ecto.Migration

  def change do
    alter table(:device_locations) do
      add :source, :string, null: false, default: "foreground"
    end
  end
end
