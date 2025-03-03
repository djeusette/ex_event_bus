defmodule ExEventBus.StateTest do
  use ExUnit.Case, async: true

  alias ExEventBus.State

  setup do
    {:ok, _handler} = start_supervised({State, [name: :test_state]})
    :ok
  end

  defmodule ExEventBus.Events.TestEvent do
  end

  defmodule ExEventBus.Subscribers.TestSubscriber1 do
  end

  defmodule ExEventBus.Subscribers.TestSubscriber2 do
  end

  describe "add_subscriber/2" do
    test "adds the subscriber for the right event" do
      assert :ok =
               State.add_subscriber(
                 :test_state,
                 ExEventBus.Events.TestEvent,
                 ExEventBus.Subscribers.TestSubscriber1
               )

      assert State.get_subscribers(:test_state, :any) == []
      assert State.get_subscribers(:test_state, ExEventBus.Subscribers.TestSubscriber1) == []
    end
  end

  describe "get_subscribers/2" do
    test "when no subscribers are registered" do
      assert State.get_subscribers(:test_state, ExEventBus.Events.TestEvent) == []
    end

    test "when subscribers are registered" do
      State.add_subscriber(
        :test_state,
        ExEventBus.Events.TestEvent,
        ExEventBus.Subscribers.TestSubscriber1
      )

      assert State.get_subscribers(:test_state, ExEventBus.Events.TestEvent) == [
               ExEventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        ExEventBus.Events.TestEvent,
        ExEventBus.Subscribers.TestSubscriber2
      )

      assert State.get_subscribers(:test_state, ExEventBus.Events.TestEvent) == [
               ExEventBus.Subscribers.TestSubscriber2,
               ExEventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        ExEventBus.Events.TestEvent,
        ExEventBus.Subscribers.TestSubscriber2
      )

      assert State.get_subscribers(:test_state, ExEventBus.Events.TestEvent) == [
               ExEventBus.Subscribers.TestSubscriber2,
               ExEventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        ExEventBus.Events.TestEvent,
        ExEventBus.Subscribers.TestSubscriber1
      )

      assert State.get_subscribers(:test_state, ExEventBus.Events.TestEvent) == [
               ExEventBus.Subscribers.TestSubscriber1,
               ExEventBus.Subscribers.TestSubscriber2
             ]
    end
  end
end
