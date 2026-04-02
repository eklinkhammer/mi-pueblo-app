defmodule FenceWeb.GeocodingController do
  use FenceWeb, :controller

  alias Fence.Geocoding

  def search(conn, %{"q" => query}) do
    result =
      try do
        Geocoding.search(query)
      catch
        :exit, _ -> {:error, :timeout}
      end

    case result do
      {:ok, results} ->
        json(conn, %{results: results})

      {:error, _} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{
          error: %{code: "geocoding_unavailable", message: "Geocoding service unavailable"}
        })
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_parameter", message: "Missing 'q' parameter"}})
  end
end
