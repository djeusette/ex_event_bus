# EventBus

EventBus provides an event bus that uses the outbox pattern.  Behind the scenes, 
it relies on Oban and ConCache.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `event_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:event_bus, "~> 0.1.0"}
  ]
end
```

## Run tests

```bash
# run only once to setup the test DB
MIX_ENV=test mix test.setup

# actually run the tests
mix test
```

## Setup

1. Create a module that defines your event bus

  ```elixir
  defmodule MyApp.EventBus do
    use EventBus, otp_app: :my_app
  end
  ```

2. Add the required config for your EventBus, that is the Oban config

  ```elixir 
  config :my_app, MyApp.EventBus,
    oban: [
      engine: Oban.Engines.Basic,
      notifier: Oban.Notifiers.Postgres,
      repo: MyApp.Repo,
      plugins: [
        {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
        {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
      ],
      queues: [
        event_bus: 2
      ]
    ]
  ```

3. Create your first events 

  ```elixir 
  defmodule MyApp.Events do
    use EventBus.Event

    defevent(MyEvent)
  end
  ```

4. Create your first event handler

  ```elixir
  defmodule MyApp.EventHandler do
    use EventBus.EventHandler,
      event_bus: MyApp.EventBus,
      events: [MyApp.Events.MyEvent]

    @impl EventBus.EventHandler
    def handle_event(%MyApp.Events.MyEvent{aggregate: %{"id" => aggregate_id}}) do
      # ... handle the event here
    end
  end
  ```

5. Add your event bus to your supervision tree

  ```elixir
  # add the event bus to your application children 

  def start(_type, _args) do 
    # ... 

    children = [
      # ...
      MyApp.EventBus,
      # ...
    ]

    # ...
  ```

6. Add your event handlers to your supervision tree

