defmodule FenceWeb.GeofenceController do
  use FenceWeb, :controller

  alias Fence.{Geofences, Groups}

  def index(conn, %{"id" => group_id}) do
    user = conn.assigns.current_user

    if Groups.member?(user.id, group_id) do
      geofences = Geofences.list_group_geofences(group_id)
      json(conn, %{geofences: Enum.map(geofences, &geofence_json/1)})
    else
      forbidden(conn)
    end
  end

  def create(conn, %{"id" => group_id} = params) do
    user = conn.assigns.current_user

    if Groups.member?(user.id, group_id) do
      attrs =
        params
        |> Map.put("group_id", group_id)
        |> Map.put("created_by_id", user.id)
        |> put_default_expiry()

      case Geofences.create_geofence(attrs) do
        {:ok, geofence} ->
          conn
          |> put_status(:created)
          |> json(%{geofence: geofence_json(geofence)})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: inspect(reason)})
      end
    else
      forbidden(conn)
    end
  end

  def show(conn, %{"gid" => group_id, "fid" => geofence_id}) do
    user = conn.assigns.current_user

    with true <- Groups.member?(user.id, group_id),
         %{} = geofence <- Geofences.get_geofence(geofence_id),
         true <- geofence.group_id == group_id do
      json(conn, %{geofence: geofence_json(geofence)})
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  def update(conn, %{"gid" => group_id, "fid" => geofence_id} = params) do
    user = conn.assigns.current_user

    with true <- Groups.member?(user.id, group_id),
         %{} = geofence <- Geofences.get_geofence(geofence_id),
         true <- geofence.group_id == group_id,
         {:ok, geofence} <- Geofences.update_geofence(geofence, params) do
      json(conn, %{geofence: geofence_json(geofence)})
    else
      nil ->
        not_found(conn)

      false ->
        forbidden(conn)

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: inspect(reason)})
    end
  end

  def delete(conn, %{"gid" => group_id, "fid" => geofence_id}) do
    user = conn.assigns.current_user

    with true <- Groups.member?(user.id, group_id),
         %{} = geofence <- Geofences.get_geofence(geofence_id),
         true <- geofence.group_id == group_id,
         {:ok, _} <- Geofences.delete_geofence(geofence) do
      send_resp(conn, :no_content, "")
    else
      nil -> not_found(conn)
      false -> forbidden(conn)
    end
  end

  # Subscriptions

  def show_subscription(conn, %{"id" => geofence_id}) do
    user = conn.assigns.current_user

    case Geofences.get_subscription(user.id, geofence_id) do
      nil ->
        json(conn, %{subscription: nil})

      sub ->
        json(conn, %{subscription: subscription_json(sub)})
    end
  end

  def upsert_subscription(conn, %{"id" => geofence_id} = params) do
    user = conn.assigns.current_user

    existing = Geofences.get_subscription(user.id, geofence_id)

    base =
      if existing do
        %{
          "notify_on_entry" => existing.notify_on_entry,
          "notify_on_exit" => existing.notify_on_exit,
          "blacklisted_user_ids" => existing.blacklisted_user_ids,
          "throttle_seconds" => existing.throttle_seconds
        }
      else
        %{}
      end

    attrs =
      base
      |> Map.merge(params)
      |> Map.put("user_id", user.id)
      |> Map.put("geofence_id", geofence_id)

    case Geofences.upsert_subscription(attrs) do
      {:ok, sub} ->
        json(conn, %{subscription: subscription_json(sub)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # Opt-outs

  def create_opt_out(conn, %{"id" => geofence_id}) do
    user = conn.assigns.current_user

    case Geofences.create_opt_out(user.id, geofence_id) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, _} -> conn |> put_status(:conflict) |> json(%{error: "Already opted out"})
    end
  end

  def delete_opt_out(conn, %{"id" => geofence_id}) do
    user = conn.assigns.current_user

    case Geofences.delete_opt_out(user.id, geofence_id) do
      {:ok, _} -> json(conn, %{ok: true})
      {:error, :not_found} -> not_found(conn)
    end
  end

  # Helpers

  defp geofence_json(geofence) do
    {lng, lat} =
      case geofence.center do
        %Geo.Point{coordinates: coords} -> coords
        _ -> {nil, nil}
      end

    %{
      id: geofence.id,
      name: geofence.name,
      description: geofence.description,
      latitude: lat,
      longitude: lng,
      radius_meters: geofence.radius_meters,
      expires_at: geofence.expires_at,
      group_id: geofence.group_id,
      created_by_id: geofence.created_by_id,
      inserted_at: geofence.inserted_at
    }
  end

  defp subscription_json(sub) do
    %{
      id: sub.id,
      geofence_id: sub.geofence_id,
      notify_on_entry: sub.notify_on_entry,
      notify_on_exit: sub.notify_on_exit,
      blacklisted_user_ids: sub.blacklisted_user_ids,
      throttle_seconds: sub.throttle_seconds
    }
  end

  defp put_default_expiry(%{"expires_at" => _} = attrs), do: attrs

  defp put_default_expiry(attrs) do
    # Default: 100 years (effectively permanent)
    far_future =
      DateTime.utc_now()
      |> DateTime.add(100 * 365 * 24 * 3600, :second)
      |> DateTime.truncate(:second)

    Map.put(attrs, "expires_at", far_future)
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
