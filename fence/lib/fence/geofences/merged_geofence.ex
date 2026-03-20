defmodule Fence.Geofences.MergedGeofence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "merged_geofences" do
    field :boundary, Geo.PostGIS.Geometry

    belongs_to :group, Fence.Groups.Group
    has_many :geofences, Fence.Geofences.Geofence, foreign_key: :merged_geofence_id

    timestamps(type: :utc_datetime)
  end

  def changeset(merged, attrs) do
    merged
    |> cast(attrs, [:group_id])
    |> validate_required([:group_id])
  end
end
