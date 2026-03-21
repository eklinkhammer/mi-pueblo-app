defmodule Fence.Locations.DeviceLocationTest do
  use Fence.DataCase, async: true

  alias Fence.Locations.DeviceLocation

  describe "changeset/2" do
    test "valid attrs" do
      changeset = DeviceLocation.changeset(%DeviceLocation{}, %{
        "user_id" => Ecto.UUID.generate(),
        "latitude" => 37.7749,
        "longitude" => -122.4194
      })
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = DeviceLocation.changeset(%DeviceLocation{}, %{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "put_point from string keys" do
      changeset = DeviceLocation.changeset(%DeviceLocation{}, %{
        "user_id" => Ecto.UUID.generate(),
        "latitude" => 37.7749,
        "longitude" => -122.4194
      })
      point = get_change(changeset, :point)
      assert %Geo.Point{coordinates: {-122.4194, 37.7749}, srid: 4326} = point
    end

    test "put_point from atom keys" do
      changeset = DeviceLocation.changeset(%DeviceLocation{}, %{
        user_id: Ecto.UUID.generate(),
        latitude: 40.7128,
        longitude: -74.0060
      })
      point = get_change(changeset, :point)
      assert %Geo.Point{coordinates: {-74.0060, 40.7128}, srid: 4326} = point
    end

    test "no point when lat/lng missing" do
      changeset = DeviceLocation.changeset(%DeviceLocation{}, %{"user_id" => Ecto.UUID.generate()})
      refute get_change(changeset, :point)
    end
  end
end
