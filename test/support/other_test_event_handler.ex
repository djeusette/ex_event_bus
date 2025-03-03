defmodule ExEventBus.OtherTestEventHandler do
  @moduledoc """
  Defines an event handler for test purposes
  """

  use ExEventBus.EventHandler,
    ex_event_bus: ExEventBus.TestEventBus,
    events: [ExEventBus.TestEvents.TestEvent, ExEventBus.TestEvents.TestEvent1]

  def handle_event(_event), do: :ok
end
