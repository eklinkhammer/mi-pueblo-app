defmodule Fence.Geofences do
  import Ecto.Query
  alias Fence.Repo
  alias Fence.Geofences.{Geofence, Subscription, OptOut}

  def create_geofence(attrs) do
    result =
      Repo.transaction(fn ->
        geofence =
          %Geofence{}
          |> Geofence.changeset(attrs)
          |> Repo.insert!()

        compute_boundary(geofence.id)
        Repo.get!(Geofence, geofence.id)
      end)

    case result do
      {:ok, geofence} ->
        enqueue_merge(geofence.group_id)
        {:ok, geofence}

      error ->
        error
    end
  end

  def get_geofence(id), do: Repo.get(Geofence, id)

  def update_geofence(%Geofence{} = geofence, attrs) do
    result =
      Repo.transaction(fn ->
        geofence =
          geofence
          |> Geofence.changeset(attrs)
          |> Repo.update!()

        compute_boundary(geofence.id)
        Repo.get!(Geofence, geofence.id)
      end)

    case result do
      {:ok, geofence} ->
        enqueue_merge(geofence.group_id)
        {:ok, geofence}

      error ->
        error
    end
  end

  def delete_geofence(%Geofence{} = geofence) do
    group_id = geofence.group_id
    result = Repo.delete(geofence)

    case result do
      {:ok, _} -> enqueue_merge(group_id)
      _ -> nil
    end

    result
  end

  def list_group_geofences(group_id) do
    from(g in Geofence,
      where: g.group_id == ^group_id,
      order_by: [desc: g.inserted_at]
    )
    |> Repo.all()
  end

  def list_active_group_geofences(group_id) do
    now = DateTime.utc_now()

    from(g in Geofence,
      where: g.group_id == ^group_id and g.expires_at > ^now,
      order_by: [desc: g.inserted_at]
    )
    |> Repo.all()
  end

  # Subscriptions

  def upsert_subscription(attrs) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace, [:notify_on_entry, :notify_on_exit, :blacklisted_user_ids, :throttle_seconds, :updated_at]},
      conflict_target: [:user_id, :geofence_id],
      returning: true
    )
  end

  def get_subscription(user_id, geofence_id) do
    Repo.get_by(Subscription, user_id: user_id, geofence_id: geofence_id)
  end

  def list_geofence_subscribers(geofence_id) do
    from(s in Subscription, where: s.geofence_id == ^geofence_id)
    |> Repo.all()
  end

  # Opt-outs

  def create_opt_out(user_id, geofence_id) do
    %OptOut{}
    |> OptOut.changeset(%{user_id: user_id, geofence_id: geofence_id})
    |> Repo.insert()
  end

  def delete_opt_out(user_id, geofence_id) do
    case Repo.get_by(OptOut, user_id: user_id, geofence_id: geofence_id) do
      nil -> {:error, :not_found}
      opt_out -> Repo.delete(opt_out)
    end
  end

  def opted_out?(user_id, geofence_id) do
    from(o in OptOut, where: o.user_id == ^user_id and o.geofence_id == ^geofence_id)
    |> Repo.exists?()
  end

  # PostGIS boundary computation

  defp compute_boundary(geofence_id) do
    Repo.query!("""
    UPDATE geofences
    SET boundary = ST_Buffer(center::geography, radius_meters)::geometry
    WHERE id = $1
    """, [Ecto.UUID.dump!(geofence_id)])
  end

  defp enqueue_merge(group_id) do
    %{group_id: group_id}
    |> Fence.Workers.MergeGeofencesWorker.new(unique: [period: 5])
    |> Oban.insert()
  end
end
