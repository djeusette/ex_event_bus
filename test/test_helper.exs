Application.ensure_all_started(:postgrex)

EventBus.Repo.start_link()

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(EventBus.Repo, :manual)
