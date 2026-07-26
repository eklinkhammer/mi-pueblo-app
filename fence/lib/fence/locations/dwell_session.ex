defmodule Fence.Locations.DwellSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "dwell_sessions" do
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_seconds, :integer
    field :center_lat, :float
    field :center_lng, :float
    field :point_count, :integer
    field :display_name, :string
    field :category, :string
    field :raw_category, :string
    field :geocoding_status, :string, default: "pending"

    belongs_to :user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(dwell_session, attrs) do
    dwell_session
    |> cast(attrs, [
      :user_id, :started_at, :ended_at, :duration_seconds,
      :center_lat, :center_lng, :point_count,
      :display_name, :category, :raw_category, :geocoding_status
    ])
    |> validate_required([:user_id, :started_at, :center_lat, :center_lng])
    |> validate_inclusion(:geocoding_status, ["pending", "categorized", "uncategorized", "failed"])
  end
end
