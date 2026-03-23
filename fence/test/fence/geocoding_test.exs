defmodule Fence.GeocodingTest do
  use ExUnit.Case, async: true

  alias Fence.Geocoding

  defp start_geocoding(plug) do
    name = :"geocoding_#{System.unique_integer([:positive])}"
    {:ok, _pid} = Geocoding.start_link(name: name, req_options: [plug: plug])
    name
  end

  test "returns parsed results on success" do
    plug = fn conn ->
      body = [
        %{
          "display_name" => "123 Main St, Springfield, IL",
          "lat" => "39.7817",
          "lon" => "-89.6501"
        },
        %{
          "display_name" => "456 Elm St, Springfield, MO",
          "lat" => "37.2090",
          "lon" => "-93.2923"
        }
      ]

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(body))
    end

    name = start_geocoding(plug)
    assert {:ok, results} = Geocoding.search("Springfield", name)
    assert length(results) == 2

    [first | _] = results
    assert first.display_name == "123 Main St, Springfield, IL"
    assert_in_delta first.lat, 39.7817, 0.001
    assert_in_delta first.lng, -89.6501, 0.001
  end

  test "returns empty list when no results" do
    plug = fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!([]))
    end

    name = start_geocoding(plug)
    assert {:ok, []} = Geocoding.search("zzzzzzzzzzz", name)
  end

  test "returns error on non-200 status" do
    plug = fn conn ->
      Plug.Conn.send_resp(conn, 500, "Server error")
    end

    name = start_geocoding(plug)
    assert {:error, _} = Geocoding.search("test", name)
  end
end
