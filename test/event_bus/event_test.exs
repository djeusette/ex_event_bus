defmodule EventBus.EventTest do
  @moduledoc """
  We use the TestEvents defined in the support directory to test the event bus.
  """

  use ExUnit.Case, async: true
  use EventBus.Event

  defmodule TestStruct do
    defstruct [:aggregate, :changes, :metadata]
  end

  describe "build_event/4" do
    test "when event is not a module" do
      assert_raise ArgumentError, ":event is not a module defining an EventBus.Event", fn ->
        build_event(:event, %EventBus.TestEvents.TestEvent{}, %{}, %{})
      end
    end

    test "when event is not a module that defines a struct" do
      assert_raise ArgumentError,
                   "EventBus.Publisher is not a module defining an EventBus.Event",
                   fn ->
                     build_event(EventBus.Publisher, %EventBus.TestEvents.TestEvent{}, %{}, %{})
                   end
    end

    test "when event is not a module that defines an EventBus event" do
      assert_raise ArgumentError,
                   "EventBus.EventTest.TestStruct is not a module defining an EventBus.Event",
                   fn ->
                     build_event(TestStruct, %EventBus.TestEvents.TestEvent{}, %{}, %{})
                   end
    end

    test "build the EventBus event" do
      assert %EventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}} =
               build_event(
                 EventBus.TestEvents.TestEvent,
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end
  end

  describe "build_events/4" do
    test "when an empty list of events is provided" do
      assert [] =
               build_events(
                 [],
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end

    test "when one event is provided in the list" do
      assert [%EventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}}] =
               build_events(
                 [EventBus.TestEvents.TestEvent],
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end

    test "when multiple events are provided in the list" do
      assert [
               %EventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}},
               %EventBus.TestEvents.TestEvent1{aggregate: %TestStruct{aggregate: %{foo: "bar"}}}
             ] =
               build_events(
                 [EventBus.TestEvents.TestEvent, EventBus.TestEvents.TestEvent1],
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end
  end

  describe "defevent/1" do
    test "creates a module with the given name" do
      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(EventBus.TestEvents.TestEvent)
    end
  end

  describe "defevents/1" do
    test "creates multiple modules with the given names" do
      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(EventBus.TestEvents.TestEvent1)

      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(EventBus.TestEvents.TestEvent2)
    end
  end

  describe "is_event" do
    test "returns true when the struct is an EventBus.Event" do
      struct = struct(EventBus.TestEvents.TestEvent, %{})
      assert is_event(struct)
    end

    test "returns false when the provided term is not an EventBus.Event" do
      refute is_event(%{})
    end
  end
end
