defmodule Fence.Geofences.GeofenceTest do
  use Fence.DataCase, async: true

  alias Fence.Geofences.Geofence

  @valid_attrs %{
    "name" => "Home",
    "radius_meters" => 500.0,
    "group_id" => Ecto.UUID.generate(),
    "expires_at" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second),
    "latitude" => 37.7749,
    "longitude" => -122.4194
  }

  describe "changeset/2" do
    test "valid attrs" do
      changeset = Geofence.changeset(%Geofence{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Geofence.changeset(%Geofence{}, Map.delete(@valid_attrs, "name"))
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires radius_meters" do
      changeset = Geofence.changeset(%Geofence{}, Map.delete(@valid_attrs, "radius_meters"))
      assert %{radius_meters: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires group_id" do
      changeset = Geofence.changeset(%Geofence{}, Map.delete(@valid_attrs, "group_id"))
      assert %{group_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires expires_at" do
      changeset = Geofence.changeset(%Geofence{}, Map.delete(@valid_attrs, "expires_at"))
      assert %{expires_at: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name max length 200" do
      changeset = Geofence.changeset(%Geofence{}, %{@valid_attrs | "name" => String.duplicate("a", 201)})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "validates radius_meters greater than 0" do
      changeset = Geofence.changeset(%Geofence{}, %{@valid_attrs | "radius_meters" => 0})
      assert %{radius_meters: [_]} = errors_on(changeset)
    end

    test "validates radius_meters max 50000" do
      changeset = Geofence.changeset(%Geofence{}, %{@valid_attrs | "radius_meters" => 50_001})
      assert %{radius_meters: [_]} = errors_on(changeset)
    end

    test "accepts radius_meters at max 50000" do
      changeset = Geofence.changeset(%Geofence{}, %{@valid_attrs | "radius_meters" => 50_000})
      assert changeset.valid?
    end

    test "put_center from string keys" do
      changeset = Geofence.changeset(%Geofence{}, @valid_attrs)
      center = get_change(changeset, :center)
      assert %Geo.Point{coordinates: {-122.4194, 37.7749}, srid: 4326} = center
    end

    test "put_center from atom keys" do
      attrs = %{
        name: "Home",
        radius_meters: 500.0,
        group_id: Ecto.UUID.generate(),
        expires_at: DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second),
        latitude: 40.7128,
        longitude: -74.0060
      }

      changeset = Geofence.changeset(%Geofence{}, attrs)
      center = get_change(changeset, :center)
      assert %Geo.Point{coordinates: {-74.0060, 40.7128}, srid: 4326} = center
    end

    test "no center when lat/lng missing" do
      attrs = Map.drop(@valid_attrs, ["latitude", "longitude"])
      changeset = Geofence.changeset(%Geofence{}, attrs)
      refute get_change(changeset, :center)
    end
  end
end
