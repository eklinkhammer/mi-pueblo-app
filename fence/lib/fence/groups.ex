defmodule Fence.Groups do
  import Ecto.Query
  alias Fence.Accounts
  alias Fence.Groups.{Group, Invite, Membership, VisibilityPair}
  alias Fence.Repo
  alias Fence.Workers.PushNotificationWorker

  def create_group(user, attrs) do
    Repo.transaction(fn ->
      group =
        %Group{}
        |> Group.changeset(Map.put(attrs, "created_by_id", user.id))
        |> Repo.insert!()

      %Membership{}
      |> Membership.changeset(%{user_id: user.id, group_id: group.id, role: "admin"})
      |> Repo.insert!()

      group
    end)
  end

  def get_group(id), do: Repo.get(Group, id)

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  def list_user_groups(user_id) do
    from(g in Group,
      join: m in Membership,
      on: m.group_id == g.id,
      where: m.user_id == ^user_id,
      select: g
    )
    |> Repo.all()
  end

  def list_members(group_id) do
    from(m in Membership,
      where: m.group_id == ^group_id,
      join: u in assoc(m, :user),
      preload: [user: u]
    )
    |> Repo.all()
  end

  def get_membership(user_id, group_id) do
    Repo.get_by(Membership, user_id: user_id, group_id: group_id)
  end

  def admin?(user_id, group_id) do
    from(m in Membership,
      where: m.user_id == ^user_id and m.group_id == ^group_id and m.role == "admin"
    )
    |> Repo.exists?()
  end

  def member?(user_id, group_id) do
    from(m in Membership,
      where: m.user_id == ^user_id and m.group_id == ^group_id
    )
    |> Repo.exists?()
  end

  def remove_member(group_id, user_id) do
    case get_membership(user_id, group_id) do
      nil ->
        {:error, :not_found}

      membership ->
        delete_visibility_pairs_for_member(group_id, user_id)
        Repo.delete(membership)
    end
  end

  @doc """
  Returns an existing unexpired invite for the group, or creates a new one.

  The `user_id` is only used as `created_by_id` when a new invite is inserted;
  if an unexpired invite already exists it is returned regardless of who created it.
  """
  def get_or_create_invite(group_id, user_id) do
    Repo.transaction(fn ->
      # Advisory lock keyed on group_id prevents concurrent duplicate inserts
      lock_key = :erlang.phash2(group_id)
      Repo.query!("SELECT pg_advisory_xact_lock($1)", [lock_key])

      now = DateTime.utc_now()

      query =
        from i in Invite,
          where: i.group_id == ^group_id and i.expires_at > ^now,
          order_by: [desc: i.inserted_at],
          limit: 1

      case Repo.one(query) do
        %Invite{} = existing ->
          existing

        nil ->
          %Invite{}
          |> Invite.changeset(%{group_id: group_id, created_by_id: user_id})
          |> Repo.insert!()
      end
    end)
  end

  def anonymous_join(code, user_attrs) do
    case validate_invite(code) do
      {:ok, invite} -> do_anonymous_join(invite, user_attrs)
      {:error, _} = error -> error
    end
  end

  defp validate_invite(code) do
    case Repo.get_by(Invite, code: code) do
      nil ->
        {:error, :invalid_code}

      %Invite{} = invite ->
        if invite_expired?(invite), do: {:error, :expired}, else: {:ok, invite}
    end
  end

  defp do_anonymous_join(invite, user_attrs) do
    Repo.transaction(fn ->
      case Accounts.create_anonymous_user(user_attrs) do
        {:ok, user} ->
          %Membership{}
          |> Membership.changeset(%{
            user_id: user.id,
            group_id: invite.group_id,
            role: "member"
          })
          |> Repo.insert!()

          create_pending_visibility_pairs(invite.group_id, user.id)

          %{type: "member_joined", group_id: invite.group_id, user_id: user.id}
          |> PushNotificationWorker.new()
          |> Oban.insert()

          group = Repo.get!(Group, invite.group_id)
          {user, group}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def join_by_invite_code(user_id, code) do
    case Repo.get_by(Invite, code: code) do
      nil ->
        {:error, :invalid_code}

      %Invite{} = invite ->
        if invite_expired?(invite) do
          {:error, :expired}
        else
          do_join(user_id, invite.group_id)
        end
    end
  end

  defp invite_expired?(%Invite{expires_at: nil}), do: false

  defp invite_expired?(%Invite{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  def update_notification_preferences(user_id, group_id, attrs) do
    case get_membership(user_id, group_id) do
      nil ->
        {:error, :not_found}

      membership ->
        membership
        |> Membership.notification_prefs_changeset(attrs)
        |> Repo.update()
    end
  end

  defp do_join(user_id, group_id) do
    %Membership{}
    |> Membership.changeset(%{user_id: user_id, group_id: group_id, role: "member"})
    |> Repo.insert()
    |> case do
      {:ok, membership} ->
        create_pending_visibility_pairs(group_id, user_id)

        %{type: "member_joined", group_id: group_id, user_id: user_id}
        |> PushNotificationWorker.new()
        |> Oban.insert()

        {:ok, Repo.preload(membership, :group)}

      {:error, %{errors: [{:user_id, _} | _]}} ->
        {:error, :already_member}

      error ->
        error
    end
  end

  # --- Visibility Pairs ---

  def create_pending_visibility_pairs(group_id, new_user_id) do
    existing_member_ids =
      from(m in Membership,
        where: m.group_id == ^group_id and m.user_id != ^new_user_id,
        select: m.user_id
      )
      |> Repo.all()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      Enum.map(existing_member_ids, fn member_id ->
        {a, b} =
          if new_user_id < member_id, do: {new_user_id, member_id}, else: {member_id, new_user_id}

        %{
          id: Ecto.UUID.generate(),
          group_id: group_id,
          user_a_id: a,
          user_b_id: b,
          status: "pending",
          granted_by_id: nil,
          granted_at: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    if entries != [] do
      Repo.insert_all(VisibilityPair, entries, on_conflict: :nothing)
    end

    :ok
  end

  def list_visibility_pairs(user_id, group_id) do
    from(vp in VisibilityPair,
      where: vp.group_id == ^group_id and (vp.user_a_id == ^user_id or vp.user_b_id == ^user_id),
      join: ua in Fence.Accounts.User,
      on: ua.id == vp.user_a_id,
      join: ub in Fence.Accounts.User,
      on: ub.id == vp.user_b_id,
      select: %{
        id: vp.id,
        user_a_id: vp.user_a_id,
        user_b_id: vp.user_b_id,
        user_a_display_name: ua.display_name,
        user_b_display_name: ub.display_name,
        status: vp.status,
        granted_by_id: vp.granted_by_id,
        granted_at: vp.granted_at
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      {other_id, other_name} =
        if row.user_a_id == user_id,
          do: {row.user_b_id, row.user_b_display_name},
          else: {row.user_a_id, row.user_a_display_name}

      %{
        id: row.id,
        other_user_id: other_id,
        other_display_name: other_name,
        status: row.status,
        granted_by_id: row.granted_by_id,
        granted_at: row.granted_at
      }
    end)
  end

  def grant_visibility(granting_user_id, group_id, other_user_id) do
    {a, b} =
      if granting_user_id < other_user_id,
        do: {granting_user_id, other_user_id},
        else: {other_user_id, granting_user_id}

    case Repo.get_by(VisibilityPair, group_id: group_id, user_a_id: a, user_b_id: b) do
      nil ->
        {:error, :not_found}

      pair ->
        pair
        |> Ecto.Changeset.change(%{
          status: "active",
          granted_by_id: granting_user_id,
          granted_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })
        |> Repo.update()
    end
  end

  def revoke_visibility(revoking_user_id, group_id, other_user_id) do
    {a, b} =
      if revoking_user_id < other_user_id,
        do: {revoking_user_id, other_user_id},
        else: {other_user_id, revoking_user_id}

    case Repo.get_by(VisibilityPair, group_id: group_id, user_a_id: a, user_b_id: b) do
      nil ->
        {:error, :not_found}

      pair ->
        pair
        |> Ecto.Changeset.change(%{
          status: "pending",
          granted_by_id: nil,
          granted_at: nil
        })
        |> Repo.update()
    end
  end

  def visible_user_ids(user_id, group_id) do
    pairs =
      from(vp in VisibilityPair,
        where:
          vp.group_id == ^group_id and vp.status == "active" and
            (vp.user_a_id == ^user_id or vp.user_b_id == ^user_id),
        select: {vp.user_a_id, vp.user_b_id}
      )
      |> Repo.all()

    pairs
    |> Enum.map(fn {a, b} -> if a == user_id, do: b, else: a end)
    |> MapSet.new()
  end

  def visible_to?(user_id_1, user_id_2, group_id) do
    {a, b} = if user_id_1 < user_id_2, do: {user_id_1, user_id_2}, else: {user_id_2, user_id_1}

    from(vp in VisibilityPair,
      where:
        vp.group_id == ^group_id and vp.user_a_id == ^a and vp.user_b_id == ^b and
          vp.status == "active"
    )
    |> Repo.exists?()
  end

  def delete_visibility_pairs_for_member(group_id, user_id) do
    from(vp in VisibilityPair,
      where: vp.group_id == ^group_id and (vp.user_a_id == ^user_id or vp.user_b_id == ^user_id)
    )
    |> Repo.delete_all()
  end
end
