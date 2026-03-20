# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :fence,
  ecto_repos: [Fence.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :fence, FenceWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: FenceWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Fence.PubSub

# JWT configuration
config :fence, Fence.Accounts.Token,
  secret_key: "dev-secret-key-change-in-prod",
  access_token_ttl: 3600,
  refresh_token_ttl: 30 * 24 * 3600

# Oban job queue
config :fence, Oban,
  repo: Fence.Repo,
  queues: [
    geofence_checks: 10,
    notifications: 10,
    maintenance: 2
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 60 * 60},
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", Fence.Workers.ExpireGeofencesWorker}
     ]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
