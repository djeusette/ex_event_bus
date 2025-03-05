defmodule ExEventBus.TestEventHandler do
  @moduledoc """
  Defines an event handler for test purposes
  """

  use ExEventBus.EventHandler,
    ex_event_bus: ExEventBus.TestEventBus,
    events: [
      "Elixir.ExEventBus.TestEvents.TestEvent",
      ExEventBus.TestEvents.TestEvent1,
      ExEventBus.TestEvents.RaiseEvent
    ]

  def handle_event(%ExEventBus.TestEvents.RaiseEvent{}), do: raise("RaiseEvent")
  def handle_event(event) when is_event(event), do: {:ok, event}
end
