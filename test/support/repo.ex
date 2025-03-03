defmodule EventBus.Repo do 
  use Ecto.Repo,
    otp_app: :event_bus,
    adapter: Ecto.Adapters.Postgres
end
