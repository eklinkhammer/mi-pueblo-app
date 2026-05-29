defmodule Fence.Geofences do
  import Ecto.Query
  require Logger
  alias Fence.Geofences.{Geofence, OptOut, Subscription}
  alias Fence.Groups.Membership, as: GroupMembership
  alias Fence.Repo
  alias Fence.Workers.{MergeGeofencesWorker, PushNotificationWorker}

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
        subscribe_creator(geofence)
        subscribe_and_notify_followers(geofence)
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
        {:replace,
         [
           :notify_on_entry,
           :notify_on_exit,
           :blacklisted_user_ids,
           :throttle_seconds,
           :updated_at
         ]},
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

  def list_user_active_geofences(user_id) do
    now = DateTime.utc_now()

    from(g in Geofence,
      join: m in GroupMembership,
      on: m.group_id == g.group_id,
      left_join: oo in OptOut,
      on: oo.geofence_id == g.id and oo.user_id == ^user_id,
      where: m.user_id == ^user_id and g.expires_at > ^now and is_nil(oo.id),
      order_by: [desc: g.inserted_at]
    )
    |> Repo.all()
  end

  # Home geofence (residents)

  def claim_home(user_id, geofence_id, group_id) do
    case Fence.Groups.get_membership(user_id, group_id) do
      nil ->
        {:error, :not_member}

      membership ->
        membership
        |> GroupMembership.set_home_changeset(%{home_geofence_id: geofence_id})
        |> Repo.update()
    end
  end

  def unclaim_home(user_id, group_id) do
    case Fence.Groups.get_membership(user_id, group_id) do
      nil ->
        {:error, :not_member}

      membership ->
        membership
        |> GroupMembership.set_home_changeset(%{home_geofence_id: nil})
        |> Repo.update()
    end
  end

  def list_residents(geofence_id) do
    from(m in GroupMembership,
      where: m.home_geofence_id == ^geofence_id,
      join: u in assoc(m, :user),
      select: %{id: u.id, display_name: u.display_name}
    )
    |> Repo.all()
  end

  # PostGIS boundary computation

  defp compute_boundary(geofence_id) do
    Repo.query!(
      """
      UPDATE geofences
      SET boundary = ST_Buffer(center::geography, radius_meters)::geometry
      WHERE id = $1
      """,
      [Ecto.UUID.dump!(geofence_id)]
    )
  end

  defp subscribe_creator(geofence) do
    case upsert_subscription(%{
           "user_id" => geofence.created_by_id,
           "geofence_id" => geofence.id,
           "notify_on_entry" => true,
           "notify_on_exit" => true
         }) do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Logger.warning(
          "Failed to auto-subscribe creator #{geofence.created_by_id} to geofence #{geofence.id}: #{inspect(changeset.errors)}"
        )
    end
  end

  defp subscribe_and_notify_followers(geofence) do
    follower_ids =
      geofence.created_by_id
      |> Fence.Groups.visible_user_ids(geofence.group_id)
      |> MapSet.delete(geofence.created_by_id)

    for follower_id <- follower_ids do
      case upsert_subscription(%{
             "user_id" => follower_id,
             "geofence_id" => geofence.id,
             "notify_on_entry" => true,
             "notify_on_exit" => true
           }) do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          Logger.warning(
            "Failed to auto-subscribe follower #{follower_id} to geofence #{geofence.id}: #{inspect(changeset.errors)}"
          )
      end
    end

    jobs =
      Enum.map(follower_ids, fn follower_id ->
        PushNotificationWorker.new(%{
          type: "geofence_created",
          geofence_id: geofence.id,
          group_id: geofence.group_id,
          creator_id: geofence.created_by_id,
          recipient_id: follower_id
        })
      end)

    case Oban.insert_all(jobs) do
      {:error, reason} ->
        Logger.warning(
          "Failed to enqueue geofence_created notifications for geofence #{geofence.id}: #{inspect(reason)}"
        )

      _inserted ->
        :ok
    end
  end

  defp enqueue_merge(group_id) do
    %{group_id: group_id}
    |> MergeGeofencesWorker.new(unique: [period: 5])
    |> Oban.insert()
  end
end
