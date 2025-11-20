defmodule ExEventBus.IntegrationTestEvents do
  @moduledoc """
  Test events for integration tests
  """

  use ExEventBus.Event

  defevents([UserCreated, UserUpdated, UserDeleted])
end
