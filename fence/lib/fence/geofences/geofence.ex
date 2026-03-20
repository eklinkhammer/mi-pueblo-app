defmodule Fence.Geofences.Geofence do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "geofences" do
    field :name, :string
    field :description, :string
    field :radius_meters, :float
    field :center, Geo.PostGIS.Geometry
    field :boundary, Geo.PostGIS.Geometry
    field :expires_at, :utc_datetime
    field :merged_geofence_id, :binary_id

    belongs_to :group, Fence.Groups.Group
    belongs_to :created_by, Fence.Accounts.User
    has_many :subscriptions, Fence.Geofences.Subscription
    has_many :opt_outs, Fence.Geofences.OptOut

    timestamps(type: :utc_datetime)
  end

  def changeset(geofence, attrs) do
    geofence
    |> cast(attrs, [:name, :description, :radius_meters, :group_id, :created_by_id, :expires_at])
    |> validate_required([:name, :radius_meters, :group_id, :expires_at])
    |> validate_number(:radius_meters, greater_than: 0, less_than_or_equal_to: 50_000)
    |> validate_length(:name, min: 1, max: 200)
    |> foreign_key_constraint(:group_id)
    |> put_center(attrs)
  end

  defp put_center(changeset, %{"latitude" => lat, "longitude" => lng})
       when is_number(lat) and is_number(lng) do
    put_change(changeset, :center, %Geo.Point{coordinates: {lng, lat}, srid: 4326})
  end

  defp put_center(changeset, %{latitude: lat, longitude: lng})
       when is_number(lat) and is_number(lng) do
    put_change(changeset, :center, %Geo.Point{coordinates: {lng, lat}, srid: 4326})
  end

  defp put_center(changeset, _), do: changeset
end
