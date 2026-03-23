defmodule Fence.Geocoding do
  @moduledoc """
  Geocoding via Nominatim (OpenStreetMap) with global rate limiting (max 1 req/sec).
  """
  use GenServer

  @nominatim_url "https://nominatim.openstreetmap.org/search"
  @min_interval_ms 1_000

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Search for an address. Returns `{:ok, results}` or `{:error, reason}`.
  Each result is `%{display_name: String.t(), lat: float(), lng: float()}`.
  """
  def search(query, name \\ __MODULE__) do
    GenServer.call(name, {:search, query}, 10_000)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    config_opts = Application.get_env(:fence, :geocoding_req_options, [])
    req_options = Keyword.merge(config_opts, Keyword.get(opts, :req_options, []))
    {:ok, %{last_request_at: nil, req_options: req_options}}
  end

  @impl true
  def handle_call({:search, query}, _from, state) do
    now = System.monotonic_time(:millisecond)

    if state.last_request_at do
      elapsed = now - state.last_request_at
      if elapsed < @min_interval_ms, do: Process.sleep(@min_interval_ms - elapsed)
    end

    {result, new_state} = do_search(query, state)
    {:reply, result, new_state}
  end

  defp do_search(query, state) do
    req_options =
      [
        url: @nominatim_url,
        headers: [{"user-agent", "Fence/1.0 (family location sharing app)"}],
        params: [q: query, format: "jsonv2", limit: 5],
        retry: false,
        connect_options: [timeout: 5_000],
        receive_timeout: 5_000
      ] ++ state.req_options

    case Req.get(req_options) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        results =
          Enum.map(body, fn item ->
            %{
              display_name: item["display_name"],
              lat: parse_float(item["lat"]),
              lng: parse_float(item["lon"])
            }
          end)

        {{:ok, results}, %{state | last_request_at: System.monotonic_time(:millisecond)}}

      {:ok, %Req.Response{status: status}} ->
        {{:error, "Nominatim returned status #{status}"}, state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp parse_float(val) when is_binary(val) do
    {f, _} = Float.parse(val)
    f
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
end
