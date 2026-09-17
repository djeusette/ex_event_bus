defmodule ExEventBus.EventHandlerTest do
  use ExUnit.Case, async: true

  alias ExEventBus.InvalidTestEventHandler
  alias ExEventBus.OtherTestEventHandler
  alias ExEventBus.Restart
  alias ExEventBus.TestEventBus
  alias ExEventBus.TestEventHandler
  alias ExEventBus.TestEvents

  setup do
    TestEventBus.clear_subscribers()
    :ok
  end

  describe "init/1" do
    test "subscribes the handler to each of its events" do
      start_supervised!({TestEventBus, []})
      start_supervised!({OtherTestEventHandler, [event_bus: TestEventBus]})

      assert TestEventBus.subscribers(TestEvents.TestEvent) == [OtherTestEventHandler]
      assert TestEventBus.subscribers(TestEvents.TestEvent1) == [OtherTestEventHandler]
      assert TestEventBus.subscribers(TestEvents.TestEvent2) == []
    end

    test "when the handler crashed and restarted, keeps a single subscription per event" do
      start_supervised!({TestEventBus, []})
      start_supervised!({OtherTestEventHandler, [event_bus: TestEventBus]})

      Restart.crash_and_await(OtherTestEventHandler)

      assert TestEventBus.subscribers(TestEvents.TestEvent) == [OtherTestEventHandler]
      assert TestEventBus.subscribers(TestEvents.TestEvent1) == [OtherTestEventHandler]
    end

    test "when the handler starts before the bus, subscribes all the same" do
      start_supervised!({OtherTestEventHandler, [event_bus: TestEventBus]})
      start_supervised!({TestEventBus, []})

      assert TestEventBus.subscribers(TestEvents.TestEvent) == [OtherTestEventHandler]
    end
  end

  describe "handle_event/1" do
    test "when not implemented, raises" do
      start_supervised!({TestEventBus, []})
      start_supervised!({InvalidTestEventHandler, [event_bus: TestEventBus]})

      assert_raise RuntimeError, "Not implemented", fn ->
        InvalidTestEventHandler.handle_event(:event)
      end
    end

    test "when implemented, handles the event" do
      start_supervised!({TestEventBus, []})
      start_supervised!({TestEventHandler, [event_bus: TestEventBus]})

      event = struct(TestEvents.TestEvent, %{})
      assert {:ok, %TestEvents.TestEvent{}} = TestEventHandler.handle_event(event)
    end
  end
end
