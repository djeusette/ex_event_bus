defmodule ExEventBus.EventHandlerTest do
  use ExUnit.Case, async: true

  alias ExEventBus.InvalidTestEventHandler
  alias ExEventBus.TestEventBus
  alias ExEventBus.TestEventHandler
  alias ExEventBus.TestEvents

  describe "InvalidTestEventHandler" do
    setup do
      {:ok, _handler} = start_supervised({TestEventBus, []})
      {:ok, _handler} = start_supervised({InvalidTestEventHandler, [event_bus: TestEventBus]})
      :ok
    end

    test "raises an error as handle_event is not implemented" do
      assert_raise RuntimeError, "Not implemented", fn ->
        InvalidTestEventHandler.handle_event(:event)
      end
    end
  end

  describe "TestEventHandler" do
    setup do
      {:ok, _handler} = start_supervised({TestEventBus, []})
      {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})
      :ok
    end

    test "handles the event as expected" do
      event = struct(TestEvents.TestEvent, %{})
      assert {:ok, %TestEvents.TestEvent{}} = TestEventHandler.handle_event(event)
    end
  end
end
