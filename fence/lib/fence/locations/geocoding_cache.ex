defmodule Fence.Locations.GeocodingCache do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "geocoding_cache" do
    field :lat_rounded, :float
    field :lng_rounded, :float
    field :display_name, :string
    field :osm_class, :string
    field :osm_type, :string
    field :category, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(cache, attrs) do
    cache
    |> cast(attrs, [:lat_rounded, :lng_rounded, :display_name, :osm_class, :osm_type, :category])
    |> validate_required([:lat_rounded, :lng_rounded])
    |> unique_constraint([:lat_rounded, :lng_rounded])
  end
end
