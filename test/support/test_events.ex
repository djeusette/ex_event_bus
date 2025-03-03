defmodule ExEventBus.TestEvents do
  @moduledoc """
  Defines events for test purposes
  """

  use ExEventBus.Event

  defevent(TestEvent)
  defevents([TestEvent1, TestEvent2])
end
