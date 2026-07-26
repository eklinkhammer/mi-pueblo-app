defmodule Fence.Locations.PlaceCategory do
  @moduledoc """
  Maps OSM class/type pairs to normalized place categories.
  """

  @category_map %{
    # Coffee shops
    {"amenity", "cafe"} => "coffee_shop",

    # Restaurants
    {"amenity", "restaurant"} => "restaurant",
    {"amenity", "fast_food"} => "restaurant",
    {"amenity", "food_court"} => "restaurant",

    # Bars
    {"amenity", "bar"} => "bar",
    {"amenity", "pub"} => "bar",
    {"amenity", "biergarten"} => "bar",
    {"amenity", "nightclub"} => "bar",

    # Gym / Fitness
    {"leisure", "fitness_centre"} => "gym",
    {"leisure", "sports_centre"} => "gym",
    {"leisure", "swimming_pool"} => "gym",

    # Hospital / Medical
    {"amenity", "hospital"} => "hospital",
    {"amenity", "clinic"} => "hospital",
    {"amenity", "doctors"} => "hospital",
    {"amenity", "dentist"} => "hospital",

    # Pharmacy
    {"amenity", "pharmacy"} => "pharmacy",

    # Grocery store
    {"shop", "supermarket"} => "grocery_store",
    {"shop", "convenience"} => "grocery_store",
    {"shop", "greengrocer"} => "grocery_store",
    {"shop", "butcher"} => "grocery_store",
    {"shop", "bakery"} => "grocery_store",

    # Shopping
    {"shop", "mall"} => "shopping",
    {"shop", "department_store"} => "shopping",
    {"shop", "clothes"} => "shopping",
    {"shop", "shoes"} => "shopping",
    {"shop", "electronics"} => "shopping",
    {"shop", "hardware"} => "shopping",
    {"shop", "furniture"} => "shopping",
    {"shop", "books"} => "shopping",

    # School / Education
    {"amenity", "school"} => "school",
    {"amenity", "university"} => "school",
    {"amenity", "college"} => "school",
    {"amenity", "kindergarten"} => "school",

    # Library
    {"amenity", "library"} => "library",

    # Place of worship
    {"amenity", "place_of_worship"} => "place_of_worship",

    # Park
    {"leisure", "park"} => "park",
    {"leisure", "garden"} => "park",
    {"leisure", "playground"} => "park",
    {"leisure", "nature_reserve"} => "park",

    # Entertainment
    {"amenity", "cinema"} => "entertainment",
    {"amenity", "theatre"} => "entertainment",
    {"leisure", "stadium"} => "entertainment",
    {"tourism", "museum"} => "entertainment",
    {"amenity", "arts_centre"} => "entertainment",
    {"leisure", "bowling_alley"} => "entertainment",

    # Office
    {"office", "company"} => "office",
    {"office", "government"} => "office",
    {"building", "office"} => "office",
    {"building", "commercial"} => "office",

    # Gas station
    {"amenity", "fuel"} => "gas_station"
  }

  @supported_categories @category_map
                        |> Map.values()
                        |> Enum.uniq()
                        |> Enum.sort()

  @doc """
  Categorize an OSM class/type pair into a normalized category.
  Returns the category string or nil if no match.
  """
  def categorize(class_name, type_name) do
    Map.get(@category_map, {class_name, type_name}) ||
      categorize_by_class(class_name)
  end

  # Fallback: if the class itself is "shop" but type isn't mapped, still call it "shopping"
  defp categorize_by_class("shop"), do: "shopping"
  defp categorize_by_class("office"), do: "office"
  defp categorize_by_class(_), do: nil

  @doc """
  Returns the list of all supported category strings.
  """
  def supported_categories, do: @supported_categories
end
