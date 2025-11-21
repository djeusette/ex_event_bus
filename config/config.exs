import Config

config :ex_event_bus,
  ecto_repos: [ExEventBus.Repo]

config :ex_event_bus, ExEventBus.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ex_event_bus_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  migration_lock: false,
  priv: "test/support",
  show_sensitive_data_on_connection_error: true,
  stacktrace: true

config :logger, level: :error

config :postgrex, :json_library, JSON
