defmodule Fence.Locations.ActiveDwell do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "active_dwells" do
    field :center_lat, :float
    field :center_lng, :float
    field :started_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :point_count, :integer, default: 1
    field :confirmed, :boolean, default: false

    belongs_to :user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(active_dwell, attrs) do
    active_dwell
    |> cast(attrs, [:user_id, :center_lat, :center_lng, :started_at, :last_seen_at, :point_count, :confirmed])
    |> validate_required([:user_id, :center_lat, :center_lng, :started_at, :last_seen_at])
    |> unique_constraint(:user_id)
  end
end
