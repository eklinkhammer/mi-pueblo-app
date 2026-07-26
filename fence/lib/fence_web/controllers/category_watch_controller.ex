defmodule FenceWeb.CategoryWatchController do
  use FenceWeb, :controller

  alias Fence.Dwells
  alias Fence.Locations.PlaceCategory

  def index(conn, _params) do
    watcher_id = conn.assigns.current_user.id
    watches = Dwells.list_category_watches(watcher_id)
    json(conn, %{watches: watches})
  end

  def create(conn, %{"watched_user_id" => watched_user_id, "category" => category}) do
    watcher_id = conn.assigns.current_user.id

    case Dwells.create_category_watch(watcher_id, watched_user_id, category) do
      {:ok, watch} ->
        conn
        |> put_status(:created)
        |> json(%{
          watch: %{
            id: watch.id,
            watched_user_id: watch.watched_user_id,
            category: watch.category,
            active: watch.active
          }
        })

      {:error, :invalid_category} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid category"})

      {:error, :no_visibility} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "No visibility to this user"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create watch", details: inspect(changeset.errors)})
    end
  end

  def delete(conn, %{"id" => watch_id}) do
    watcher_id = conn.assigns.current_user.id

    case Dwells.delete_category_watch(watcher_id, watch_id) do
      {:ok, _} ->
        json(conn, %{ok: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Watch not found"})
    end
  end

  def categories(conn, _params) do
    json(conn, %{categories: PlaceCategory.supported_categories()})
  end
end
