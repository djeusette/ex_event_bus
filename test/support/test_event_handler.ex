defmodule EventBus.TestEventHandler do
  @moduledoc """
  Defines an event handler for test purposes
  """

  use EventBus.EventHandler,
    event_bus: EventBus.TestEventBus,
    events: ["Elixir.EventBus.TestEvents.TestEvent", EventBus.TestEvents.TestEvent1]

  def handle_event(event) when is_event(event), do: {:ok, event}
end
