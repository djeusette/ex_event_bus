defmodule ExEventBus.TestEventBus do
  @moduledoc """
  Defines an EventBus for test purposes
  """

  use ExEventBus,
    otp_app: :ex_event_bus,
    oban: [
      engine: Oban.Engines.Basic,
      testing: :manual,
      notifier: Oban.Notifiers.PG,
      repo: ExEventBus.Repo,
      plugins: [
        {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
        {Oban.Plugins.Pruner, max_age: 60 * 2}
      ],
      queues: [
        ex_event_bus: 3
      ]
    ]
end
