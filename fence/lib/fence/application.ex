defmodule Fence.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    fcm_children =
      if Application.get_env(:fence, :fcm_credentials) do
        credentials = Application.fetch_env!(:fence, :fcm_credentials)

        [
          {Goth, name: Fence.Goth, source: {:service_account, credentials, []}},
          Fence.FCM
        ]
      else
        []
      end

    google_jwks_children =
      if Application.get_env(:fence, :start_google_jwks, true) do
        [Fence.Accounts.GoogleToken.KeyStore]
      else
        []
      end

    children =
      [
        FenceWeb.Telemetry,
        Fence.Repo,
        {DNSCluster, query: Application.get_env(:fence, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Fence.PubSub},
        {Oban, Application.fetch_env!(:fence, Oban)},
        Fence.Geocoding,
        FenceWeb.Presence
      ] ++ google_jwks_children ++ fcm_children ++ [FenceWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fence.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FenceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
