defmodule ExEventBus.Repo do
  use Ecto.Repo,
    otp_app: :ex_event_bus,
    adapter: Ecto.Adapters.Postgres

  use ExEventBus.EctoRepoWrapper, ex_event_bus: ExEventBus.TestEventBus
end
