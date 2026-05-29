defmodule FenceWeb.SubscriptionController do
  use FenceWeb, :controller

  alias Fence.Subscriptions

  def show(conn, _params) do
    user = conn.assigns.current_user
    {:ok, subscription} = Subscriptions.get_or_create_subscription(user.id)
    tier = Subscriptions.active_tier(user.id)
    limits = Subscriptions.limits_for_tier(tier)

    json(conn, %{
      subscription: %{
        tier: tier,
        status: subscription.status,
        store: subscription.store,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        expires_at: subscription.expires_at
      },
      limits: format_limits(limits),
      usage: %{
        groups_created: Subscriptions.count_created_groups(user.id)
      }
    })
  end

  def limits(conn, _params) do
    tiers = Subscriptions.tier_limits()

    json(conn, %{
      tiers:
        Enum.map(tiers, fn {tier, limits} ->
          %{tier: tier, limits: format_limits(limits)}
        end)
    })
  end

  def restore(conn, _params) do
    user = conn.assigns.current_user
    {:ok, subscription} = Subscriptions.get_or_create_subscription(user.id)
    tier = Subscriptions.active_tier(user.id)
    limits = Subscriptions.limits_for_tier(tier)

    json(conn, %{
      subscription: %{
        tier: tier,
        status: subscription.status,
        store: subscription.store,
        current_period_start: subscription.current_period_start,
        current_period_end: subscription.current_period_end,
        expires_at: subscription.expires_at
      },
      limits: format_limits(limits)
    })
  end

  defp format_limits(limits) do
    %{
      max_groups: format_limit_value(limits.max_groups),
      max_members: limits.max_members,
      max_geofences: format_limit_value(limits.max_geofences),
      history_days: limits.history_days
    }
  end

  defp format_limit_value(:unlimited), do: -1
  defp format_limit_value(n), do: n
end
