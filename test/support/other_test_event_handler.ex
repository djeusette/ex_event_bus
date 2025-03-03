defmodule EventBus.OtherTestEventHandler do
  @moduledoc """
  Defines an event handler for test purposes
  """

  use EventBus.EventHandler,
    event_bus: EventBus.TestEventBus,
    events: [EventBus.TestEvents.TestEvent, EventBus.TestEvents.TestEvent1]

  def handle_event(_event), do: :ok
end
