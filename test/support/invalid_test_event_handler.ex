defmodule ExEventBus.InvalidTestEventHandler do
  @moduledoc """
  Defines an invaliad event handler for test purposes
  """

  use ExEventBus.EventHandler,
    ex_event_bus: ExEventBus.TestEventBus,
    events: [ExEventBus.TestEvents.TestEvent, ExEventBus.TestEvents.TestEvent1]
end
