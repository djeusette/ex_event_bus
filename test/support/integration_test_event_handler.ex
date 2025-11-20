defmodule ExEventBus.IntegrationTestEventHandler do
  @moduledoc """
  Event handler for integration tests
  """

  use ExEventBus.EventHandler,
    ex_event_bus: ExEventBus.TestEventBus,
    events: [
      ExEventBus.IntegrationTestEvents.UserCreated,
      ExEventBus.IntegrationTestEvents.UserUpdated,
      ExEventBus.IntegrationTestEvents.UserDeleted
    ]

  def handle_event(event) when is_event(event), do: {:ok, event}
end
