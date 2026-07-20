defmodule Fence.Subscriptions.RevenueCat do
  @moduledoc """
  REST client for RevenueCat subscriber lookup.
  """
  require Logger

  def get_subscriber(app_user_id) do
    api_key = Application.get_env(:fence, :revenuecat_api_key)

    if api_key do
      case Req.get("https://api.revenuecat.com/v1/subscribers/#{app_user_id}",
             headers: [{"Authorization", "Bearer #{api_key}"}]
           ) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: status}} ->
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("RevenueCat API error: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, :api_key_not_configured}
    end
  end

  def tier_from_entitlements(subscriber_data) do
    entitlements = get_in(subscriber_data, ["subscriber", "entitlements"]) || %{}

    cond do
      active_entitlement?(entitlements, "leader") -> "village_leader"
      active_entitlement?(entitlements, "elder") -> "village_elder"
      true -> "village_member"
    end
  end

  defp active_entitlement?(entitlements, name) do
    case Map.get(entitlements, name) do
      %{"expires_date" => nil} ->
        true

      %{"expires_date" => expires} ->
        case DateTime.from_iso8601(expires) do
          {:ok, dt, _} -> DateTime.compare(dt, DateTime.utc_now()) == :gt
          _ -> false
        end

      _ ->
        false
    end
  end
end
