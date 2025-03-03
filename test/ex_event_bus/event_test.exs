defmodule ExEventBus.EventTest do
  @moduledoc """
  We use the TestEvents defined in the support directory to test the event bus.
  """

  use ExUnit.Case, async: true
  use ExEventBus.Event

  defmodule TestStruct do
    defstruct [:aggregate, :changes, :metadata]
  end

  describe "build_event/4" do
    test "when event is not a module" do
      assert_raise ArgumentError, ":event is not a module defining an ExEventBus.Event", fn ->
        build_event(:event, %ExEventBus.TestEvents.TestEvent{}, %{}, %{})
      end
    end

    test "when event is not a module that defines a struct" do
      assert_raise ArgumentError,
                   "ExEventBus.Publisher is not a module defining an ExEventBus.Event",
                   fn ->
                     build_event(
                       ExEventBus.Publisher,
                       %ExEventBus.TestEvents.TestEvent{},
                       %{},
                       %{}
                     )
                   end
    end

    test "when event is not a module that defines an ExEventBus event" do
      assert_raise ArgumentError,
                   "ExEventBus.EventTest.TestStruct is not a module defining an ExEventBus.Event",
                   fn ->
                     build_event(TestStruct, %ExEventBus.TestEvents.TestEvent{}, %{}, %{})
                   end
    end

    test "build the ExEventBus event" do
      assert %ExEventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}} =
               build_event(
                 ExEventBus.TestEvents.TestEvent,
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
      assert [%ExEventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}}] =
               build_events(
                 [ExEventBus.TestEvents.TestEvent],
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end

    test "when multiple events are provided in the list" do
      assert [
               %ExEventBus.TestEvents.TestEvent{aggregate: %TestStruct{aggregate: %{foo: "bar"}}},
               %ExEventBus.TestEvents.TestEvent1{aggregate: %TestStruct{aggregate: %{foo: "bar"}}}
             ] =
               build_events(
                 [ExEventBus.TestEvents.TestEvent, ExEventBus.TestEvents.TestEvent1],
                 %TestStruct{aggregate: %{foo: "bar"}},
                 %{},
                 %{}
               )
    end
  end

  describe "defevent/1" do
    test "creates a module with the given name" do
      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(ExEventBus.TestEvents.TestEvent)
    end
  end

  describe "defevents/1" do
    test "creates multiple modules with the given names" do
      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(ExEventBus.TestEvents.TestEvent1)

      assert %_{aggregate: nil, changes: nil, metadata: nil} =
               struct(ExEventBus.TestEvents.TestEvent2)
    end
  end

  describe "is_event" do
    test "returns true when the struct is an ExEventBus.Event" do
      struct = struct(ExEventBus.TestEvents.TestEvent, %{})
      assert is_event(struct)
    end

    test "returns false when the provided term is not an ExEventBus.Event" do
      refute is_event(%{})
    end
  end
end
