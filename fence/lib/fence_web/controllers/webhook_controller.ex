defmodule FenceWeb.WebhookController do
  use FenceWeb, :controller
  require Logger

  alias Fence.Subscriptions

  def revenuecat(conn, params) do
    expected_secret = Application.get_env(:fence, :revenuecat_webhook_secret)

    with true <- expected_secret != nil,
         auth_header <- get_req_header(conn, "authorization"),
         true <- auth_header == ["Bearer #{expected_secret}"] do
      case Subscriptions.process_webhook(params) do
        {:ok, _} ->
          json(conn, %{ok: true})

        :ok ->
          json(conn, %{ok: true})

        {:error, reason} ->
          Logger.warning("RevenueCat webhook processing failed: #{inspect(reason)}")
          json(conn, %{ok: true})
      end
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
    end
  end
end
