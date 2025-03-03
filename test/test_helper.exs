Application.ensure_all_started(:postgrex)

ExEventBus.Repo.start_link()

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(ExEventBus.Repo, :manual)
