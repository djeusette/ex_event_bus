defmodule EventBus.InvalidTestEventHandler do
  @moduledoc """
  Defines an invaliad event handler for test purposes
  """

  use EventBus.EventHandler,
    event_bus: EventBus.TestEventBus,
    events: [EventBus.TestEvents.TestEvent, EventBus.TestEvents.TestEvent1]
end
