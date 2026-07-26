defmodule Fence.Dwells do
  import Ecto.Query

  alias Fence.Groups
  alias Fence.Locations.{CategoryWatch, DwellSession, PlaceCategory}
  alias Fence.Repo

  @doc """
  List recent categorized dwell sessions for a user.
  Options: `:limit` (default 20), `:category` (optional filter).
  """
  def list_user_dwell_sessions(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    category = Keyword.get(opts, :category)

    query =
      from(ds in DwellSession,
        where: ds.user_id == ^user_id and ds.geocoding_status == "categorized",
        order_by: [desc: ds.started_at],
        limit: ^limit
      )

    query =
      if category do
        from(ds in query, where: ds.category == ^category)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Create a category watch. Validates that watcher has visibility to watched user.
  """
  def create_category_watch(watcher_id, watched_user_id, category) do
    if category not in PlaceCategory.supported_categories() do
      {:error, :invalid_category}
    else
      visible_groups = Groups.visible_group_ids(watcher_id, watched_user_id)

      if Enum.empty?(visible_groups) do
        {:error, :no_visibility}
      else
        %CategoryWatch{}
        |> CategoryWatch.changeset(%{
          watcher_id: watcher_id,
          watched_user_id: watched_user_id,
          category: category
        })
        |> Repo.insert()
      end
    end
  end

  @doc """
  Delete a category watch by id, ensuring the caller owns it.
  """
  def delete_category_watch(watcher_id, watch_id) do
    case Repo.get_by(CategoryWatch, id: watch_id, watcher_id: watcher_id) do
      nil -> {:error, :not_found}
      watch -> Repo.delete(watch)
    end
  end

  @doc """
  List category watches set up by a watcher, with watched user display_name.
  """
  def list_category_watches(watcher_id) do
    from(w in CategoryWatch,
      where: w.watcher_id == ^watcher_id,
      join: u in Fence.Accounts.User,
      on: u.id == w.watched_user_id,
      select: %{
        id: w.id,
        watched_user_id: w.watched_user_id,
        watched_user_name: u.display_name,
        category: w.category,
        active: w.active,
        throttle_seconds: w.throttle_seconds
      },
      order_by: [asc: u.display_name, asc: w.category]
    )
    |> Repo.all()
  end

  @doc """
  List active watches for a given watched user and category. Used by notification worker.
  """
  def list_active_watches_for(watched_user_id, category) do
    from(w in CategoryWatch,
      where:
        w.watched_user_id == ^watched_user_id and
          w.category == ^category and
          w.active == true
    )
    |> Repo.all()
  end
end
