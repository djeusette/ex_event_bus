import Config

config :event_bus,
  ecto_repos: [EventBus.Repo]

config :event_bus, EventBus.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "eventbus_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  migration_lock: false,
  priv: "test/support",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true

config :postgrex, :json_library, JSON
