defmodule Fence.Locations.DeviceLocation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_locations" do
    field :point, Geo.PostGIS.Geometry
    field :accuracy, :float
    field :altitude, :float
    field :speed, :float
    field :bearing, :float
    field :battery_level, :float

    belongs_to :user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(location, attrs) do
    location
    |> cast(attrs, [:user_id, :accuracy, :altitude, :speed, :bearing, :battery_level])
    |> validate_required([:user_id])
    |> put_point(attrs)
  end

  defp put_point(changeset, %{"latitude" => lat, "longitude" => lng})
       when is_number(lat) and is_number(lng) do
    put_change(changeset, :point, %Geo.Point{coordinates: {lng, lat}, srid: 4326})
  end

  defp put_point(changeset, %{latitude: lat, longitude: lng})
       when is_number(lat) and is_number(lng) do
    put_change(changeset, :point, %Geo.Point{coordinates: {lng, lat}, srid: 4326})
  end

  defp put_point(changeset, _), do: changeset
end
