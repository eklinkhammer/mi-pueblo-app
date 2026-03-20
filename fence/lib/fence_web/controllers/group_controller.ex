defmodule FenceWeb.GroupController do
  use FenceWeb, :controller

  alias Fence.Groups

  def index(conn, _params) do
    groups = Groups.list_user_groups(conn.assigns.current_user.id)
    json(conn, %{groups: Enum.map(groups, &group_json/1)})
  end

  def create(conn, params) do
    case Groups.create_group(conn.assigns.current_user, params) do
      {:ok, group} ->
        conn
        |> put_status(:created)
        |> json(%{group: group_json(group)})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.is_member?(user.id, group.id) do
      json(conn, %{group: group_json(group)})
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.is_admin?(user.id, group.id),
         {:ok, group} <- Groups.update_group(group, params) do
      json(conn, %{group: group_json(group)})
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.is_admin?(user.id, group.id),
         {:ok, _} <- Groups.delete_group(group) do
      send_resp(conn, :no_content, "")
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  def join(conn, %{"invite_code" => code}) do
    user = conn.assigns.current_user

    case Groups.join_by_invite_code(user.id, code) do
      {:ok, membership} ->
        json(conn, %{group: group_json(membership.group)})

      {:error, :invalid_code} ->
        conn |> put_status(:not_found) |> json(%{error: "Invalid invite code"})

      {:error, :expired} ->
        conn |> put_status(:gone) |> json(%{error: "Invite code expired"})

      {:error, :already_member} ->
        conn |> put_status(:conflict) |> json(%{error: "Already a member"})
    end
  end

  def members(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = _group <- Groups.get_group(id),
         true <- Groups.is_member?(user.id, id) do
      memberships = Groups.list_members(id)

      json(conn, %{
        members:
          Enum.map(memberships, fn m ->
            %{
              id: m.user.id,
              display_name: m.user.display_name,
              email: m.user.email,
              role: m.role,
              joined_at: m.inserted_at
            }
          end)
      })
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  def remove_member(conn, %{"id" => group_id, "user_id" => target_user_id}) do
    user = conn.assigns.current_user

    with true <- Groups.is_admin?(user.id, group_id),
         {:ok, _} <- Groups.remove_member(group_id, target_user_id) do
      send_resp(conn, :no_content, "")
    else
      false -> forbidden(conn)
      {:error, :not_found} -> not_found(conn)
    end
  end

  def create_invite(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    with true <- Groups.is_admin?(user.id, group_id),
         {:ok, invite} <- Groups.create_invite(group_id, user.id) do
      conn
      |> put_status(:created)
      |> json(%{invite: %{code: invite.code, expires_at: invite.expires_at}})
    else
      false -> forbidden(conn)
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not create invite"})
    end
  end

  defp group_json(group) do
    %{
      id: group.id,
      name: group.name,
      inserted_at: group.inserted_at
    }
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: "Not found"})
  end

  defp forbidden(conn) do
    conn |> put_status(:forbidden) |> json(%{error: "Forbidden"})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
