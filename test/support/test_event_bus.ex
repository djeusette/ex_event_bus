defmodule EventBus.TestEventBus do
  @moduledoc """
  Defines an EventBus for test purposes
  """

  use EventBus,
    otp_app: :event_bus,
    oban: [
      engine: Oban.Engines.Basic,
      testing: :manual,
      notifier: Oban.Notifiers.PG,
      repo: EventBus.Repo,
      plugins: [
        {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
        {Oban.Plugins.Pruner, max_age: 60 * 2}
      ],
      queues: [
        event_bus: 3
      ]
    ]
end
