defmodule Fence.Workers.DwellCategorizationWorker do
  use Oban.Worker, queue: :geocoding, max_attempts: 3

  require Logger
  import Ecto.Query

  alias Fence.Geocoding
  alias Fence.Locations.{DwellSession, GeocodingCache, PlaceCategory}
  alias Fence.Repo
  alias Fence.Workers.CategoryWatchNotificationWorker

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dwell_session_id" => session_id}}) do
    case Repo.get(DwellSession, session_id) do
      nil ->
        Logger.warning("[DwellCategorization] Session #{session_id} not found")
        :ok

      session ->
        categorize_session(session)
    end
  end

  defp categorize_session(%DwellSession{} = session) do
    lat_rounded = Float.round(session.center_lat, 4)
    lng_rounded = Float.round(session.center_lng, 4)

    case check_cache(lat_rounded, lng_rounded) do
      {:ok, cached} ->
        update_session_from_cache(session, cached)

      :miss ->
        reverse_geocode_and_update(session, lat_rounded, lng_rounded)
    end
  end

  defp check_cache(lat_rounded, lng_rounded) do
    case from(c in GeocodingCache,
           where: c.lat_rounded == ^lat_rounded and c.lng_rounded == ^lng_rounded,
           limit: 1
         )
         |> Repo.one() do
      nil -> :miss
      cached -> {:ok, cached}
    end
  end

  defp update_session_from_cache(session, cached) do
    status = if cached.category, do: "categorized", else: "uncategorized"

    session
    |> DwellSession.changeset(%{
      display_name: cached.display_name,
      category: cached.category,
      raw_category: "#{cached.osm_class}/#{cached.osm_type}",
      geocoding_status: status
    })
    |> Repo.update()

    if cached.category do
      enqueue_notification(session.id)
    end

    :ok
  end

  defp reverse_geocode_and_update(session, lat_rounded, lng_rounded) do
    case Geocoding.reverse(session.center_lat, session.center_lng) do
      {:ok, result} ->
        category = PlaceCategory.categorize(result.class, result.type)
        raw_category = "#{result.class}/#{result.type}"
        status = if category, do: "categorized", else: "uncategorized"

        session
        |> DwellSession.changeset(%{
          display_name: result.display_name,
          category: category,
          raw_category: raw_category,
          geocoding_status: status
        })
        |> Repo.update()

        upsert_cache(lat_rounded, lng_rounded, result, category)

        if category do
          enqueue_notification(session.id)
        end

        :ok

      {:error, reason} ->
        Logger.warning("[DwellCategorization] Geocoding failed: #{inspect(reason)}")

        session
        |> DwellSession.changeset(%{geocoding_status: "failed"})
        |> Repo.update()

        {:error, reason}
    end
  end

  defp upsert_cache(lat_rounded, lng_rounded, result, category) do
    %GeocodingCache{}
    |> GeocodingCache.changeset(%{
      lat_rounded: lat_rounded,
      lng_rounded: lng_rounded,
      display_name: result.display_name,
      osm_class: result.class,
      osm_type: result.type,
      category: category
    })
    |> Repo.insert(
      on_conflict: {:replace, [:display_name, :osm_class, :osm_type, :category, :updated_at]},
      conflict_target: [:lat_rounded, :lng_rounded]
    )
  end

  defp enqueue_notification(dwell_session_id) do
    %{dwell_session_id: dwell_session_id}
    |> CategoryWatchNotificationWorker.new()
    |> Oban.insert()
  end
end
