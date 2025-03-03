defmodule EventBus.TestEvents do
  @moduledoc """
  Defines events for test purposes
  """

  use EventBus.Event

  defevent(TestEvent)
  defevents([TestEvent1, TestEvent2])
end
