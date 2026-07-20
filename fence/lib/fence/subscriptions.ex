defmodule Fence.Subscriptions do
  import Ecto.Query
  alias Fence.Groups.Group
  alias Fence.Geofences.Geofence
  alias Fence.Groups.Membership
  alias Fence.Subscriptions.Subscription
  alias Fence.Repo

  @tier_limits %{
    "village_member" => %{max_groups: 1, max_members: 10, max_geofences: 3, history_days: 7},
    "village_elder" => %{
      max_groups: 3,
      max_members: 50,
      max_geofences: :unlimited,
      history_days: 90
    },
    "village_leader" => %{
      max_groups: :unlimited,
      max_members: 100,
      max_geofences: :unlimited,
      history_days: 90
    }
  }

  def tier_limits, do: @tier_limits

  def get_or_create_subscription(user_id) do
    case Repo.get_by(Subscription, user_id: user_id) do
      nil ->
        %Subscription{}
        |> Subscription.changeset(%{user_id: user_id, tier: "village_member", status: "active"})
        |> Repo.insert()

      subscription ->
        {:ok, subscription}
    end
  end

  def active_tier(user_id) do
    case Repo.get_by(Subscription, user_id: user_id) do
      nil -> "village_member"
      %{status: "active", tier: tier} -> tier
      %{status: "grace_period", tier: tier} -> tier
      _expired_or_cancelled -> "village_member"
    end
  end

  def can_create_group?(user_id) do
    tier = active_tier(user_id)
    limit = @tier_limits[tier].max_groups

    case limit do
      :unlimited -> true
      n -> count_created_groups(user_id) < n
    end
  end

  def can_create_geofence?(group_id) do
    group = Repo.get!(Group, group_id)
    tier = active_tier(group.created_by_id)
    limit = @tier_limits[tier].max_geofences

    case limit do
      :unlimited -> true
      n -> count_group_geofences(group_id) < n
    end
  end

  def can_add_member?(group_id) do
    group = Repo.get!(Group, group_id)
    tier = active_tier(group.created_by_id)
    limit = @tier_limits[tier].max_members
    count_members(group_id) < limit
  end

  def history_retention_days(user_id) do
    tier = active_tier(user_id)
    @tier_limits[tier].history_days
  end

  def limits_for_tier(tier) do
    Map.get(@tier_limits, tier, @tier_limits["village_member"])
  end

  # Count helpers

  def count_created_groups(user_id) do
    from(g in Group, where: g.created_by_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_members(group_id) do
    from(m in Membership, where: m.group_id == ^group_id)
    |> Repo.aggregate(:count, :id)
  end

  def count_group_geofences(group_id) do
    # Count non-home geofences: exclude geofences that are claimed as home by any member
    home_geofence_ids =
      from(m in Membership,
        where: m.group_id == ^group_id and not is_nil(m.home_geofence_id),
        select: m.home_geofence_id
      )

    from(g in Geofence,
      where: g.group_id == ^group_id and g.id not in subquery(home_geofence_ids)
    )
    |> Repo.aggregate(:count, :id)
  end

  # Webhook processing

  def process_webhook(%{"event" => event} = payload) do
    case event do
      "INITIAL_PURCHASE" -> handle_purchase(payload)
      "RENEWAL" -> handle_purchase(payload)
      "PRODUCT_CHANGE" -> handle_purchase(payload)
      "CANCELLATION" -> handle_cancellation(payload)
      "EXPIRATION" -> handle_expiration(payload)
      "BILLING_ISSUE" -> handle_billing_issue(payload)
      "SUBSCRIBER_ALIAS" -> :ok
      _ -> :ok
    end
  end

  defp handle_purchase(%{"app_user_id" => app_user_id} = payload) do
    product_id = deep_get(payload, ["product_id"])
    tier = product_id_to_tier(product_id)

    case get_or_create_subscription(app_user_id) do
      {:ok, sub} ->
        sub
        |> Subscription.changeset(%{
          tier: tier,
          status: "active",
          rc_customer_id: deep_get(payload, ["original_app_user_id"]),
          rc_product_id: product_id,
          rc_entitlement_id: deep_get(payload, ["entitlement_id"]),
          store: deep_get(payload, ["store"]),
          current_period_start: parse_datetime(deep_get(payload, ["period_start"])),
          current_period_end: parse_datetime(deep_get(payload, ["period_end"])),
          expires_at: parse_datetime(deep_get(payload, ["expiration_at"]))
        })
        |> Repo.update()

      error ->
        error
    end
  end

  defp handle_cancellation(%{"app_user_id" => app_user_id}) do
    case Repo.get_by(Subscription, user_id: app_user_id) do
      nil ->
        :ok

      sub ->
        sub
        |> Subscription.changeset(%{status: "cancelled"})
        |> Repo.update()
    end
  end

  defp handle_expiration(%{"app_user_id" => app_user_id}) do
    case Repo.get_by(Subscription, user_id: app_user_id) do
      nil ->
        :ok

      sub ->
        sub
        |> Subscription.changeset(%{status: "expired"})
        |> Repo.update()
    end
  end

  defp handle_billing_issue(%{"app_user_id" => app_user_id}) do
    case Repo.get_by(Subscription, user_id: app_user_id) do
      nil ->
        :ok

      sub ->
        sub
        |> Subscription.changeset(%{status: "grace_period"})
        |> Repo.update()
    end
  end

  def product_id_to_tier(product_id) do
    case product_id do
      "fence_leader_monthly" -> "village_leader"
      "fence_elder_monthly" -> "village_elder"
      _ -> "village_member"
    end
  end

  defp deep_get(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key)
        _ -> nil
      end
    end)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end
end
