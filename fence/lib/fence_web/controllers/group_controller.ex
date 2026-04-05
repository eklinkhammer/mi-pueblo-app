defmodule FenceWeb.GroupController do
  use FenceWeb, :controller

  alias Fence.Groups

  def index(conn, _params) do
    groups = Groups.list_user_groups_with_sharing_count(conn.assigns.current_user.id)

    json(conn, %{
      groups:
        Enum.map(groups, fn {group, sharing_count} ->
          group_json(group) |> Map.put(:sharing_count, sharing_count)
        end)
    })
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
        |> json(%{error: %{code: "validation_failed", message: inspect(reason)}})
    end
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.member?(user.id, group.id) do
      json(conn, %{group: group_json(group)})
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.admin?(user.id, group.id),
         {:ok, group} <- Groups.update_group(group, params) do
      json(conn, %{group: group_json(group)})
    else
      nil ->
        not_found(conn)

      false ->
        forbidden(conn)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = group <- Groups.get_group(id),
         true <- Groups.admin?(user.id, group.id),
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
        conn
        |> put_status(:not_found)
        |> json(%{error: %{code: "invalid_invite_code", message: "Invalid invite code"}})

      {:error, :expired} ->
        conn
        |> put_status(:gone)
        |> json(%{error: %{code: "invite_code_expired", message: "Invite code expired"}})

      {:error, :already_member} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: %{code: "already_member", message: "Already a member"}})
    end
  end

  def members(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = _group <- Groups.get_group(id),
         true <- Groups.member?(user.id, id) do
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

    with true <- Groups.admin?(user.id, group_id),
         {:ok, _} <- Groups.remove_member(group_id, target_user_id) do
      send_resp(conn, :no_content, "")
    else
      false -> forbidden(conn)
      {:error, :not_found} -> not_found(conn)
    end
  end

  def create_invite(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    with true <- Groups.admin?(user.id, group_id),
         {:ok, invite} <- Groups.get_or_create_invite(group_id, user.id) do
      conn
      |> put_status(:created)
      |> json(%{invite: %{code: invite.code, expires_at: invite.expires_at}})
    else
      false ->
        forbidden(conn)

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{code: "could_not_create_invite", message: "Could not create invite"}})
    end
  end

  def show_sharing_mode(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    case Groups.get_membership(user.id, group_id) do
      nil ->
        forbidden(conn)

      membership ->
        json(conn, %{sharing_mode: membership.sharing_mode})
    end
  end

  def update_sharing_mode(conn, %{"id" => group_id, "sharing_mode" => mode}) do
    user = conn.assigns.current_user

    case Groups.update_sharing_mode(user.id, group_id, mode) do
      {:ok, membership} ->
        json(conn, %{sharing_mode: membership.sharing_mode})

      {:error, :not_found} ->
        forbidden(conn)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def show_notification_preferences(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    case Groups.get_membership(user.id, group_id) do
      nil ->
        forbidden(conn)

      membership ->
        json(conn, %{
          silence_all_notifications: membership.silence_all_notifications,
          silence_home_notifications: membership.silence_home_notifications,
          notify_household: membership.notify_household
        })
    end
  end

  def update_notification_preferences(conn, %{"id" => group_id} = params) do
    user = conn.assigns.current_user

    case Groups.update_notification_preferences(user.id, group_id, params) do
      {:ok, membership} ->
        json(conn, %{
          silence_all_notifications: membership.silence_all_notifications,
          silence_home_notifications: membership.silence_home_notifications,
          notify_household: membership.notify_household
        })

      {:error, :not_found} ->
        forbidden(conn)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
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
    conn |> put_status(:not_found) |> json(%{error: %{code: "not_found", message: "Not found"}})
  end

  defp forbidden(conn) do
    conn |> put_status(:forbidden) |> json(%{error: %{code: "forbidden", message: "Forbidden"}})
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
