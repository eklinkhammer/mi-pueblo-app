defmodule Fence.Groups do
  import Ecto.Query
  alias Fence.Groups.{Group, Invite, Membership}
  alias Fence.Repo

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
      nil -> {:error, :not_found}
      membership -> Repo.delete(membership)
    end
  end

  def create_invite(group_id, user_id) do
    %Invite{}
    |> Invite.changeset(%{group_id: group_id, created_by_id: user_id})
    |> Repo.insert()
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

  defp do_join(user_id, group_id) do
    %Membership{}
    |> Membership.changeset(%{user_id: user_id, group_id: group_id, role: "member"})
    |> Repo.insert()
    |> case do
      {:ok, membership} -> {:ok, Repo.preload(membership, :group)}
      {:error, %{errors: [{:user_id, _} | _]}} -> {:error, :already_member}
      error -> error
    end
  end
end
