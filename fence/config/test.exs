import Config

# Configure your database
config :fence, Fence.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "fence_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fence, FenceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "MAyWe3TiAROH/hwvhrod3YfUqbmTxuWqRXxVOMv6Qa0R+w5gemc6dxHv5vPPCnmR",
  server: System.get_env("PHX_SERVER") == "true"

# Oban manual mode for tests - prevents cascading worker execution
config :fence, Oban, testing: :manual

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix,
  sort_verified_routes_query_params: true
