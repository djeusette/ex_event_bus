defmodule EventBus.StateTest do
  use ExUnit.Case, async: true

  alias EventBus.State

  setup do
    {:ok, _handler} = start_supervised({State, [name: :test_state]})
    :ok
  end

  defmodule EventBus.Events.TestEvent do
  end

  defmodule EventBus.Subscribers.TestSubscriber1 do
  end

  defmodule EventBus.Subscribers.TestSubscriber2 do
  end

  describe "add_subscriber/2" do
    test "adds the subscriber for the right event" do
      assert :ok =
               State.add_subscriber(
                 :test_state,
                 EventBus.Events.TestEvent,
                 EventBus.Subscribers.TestSubscriber1
               )

      assert State.get_subscribers(:test_state, :any) == []
      assert State.get_subscribers(:test_state, EventBus.Subscribers.TestSubscriber1) == []
    end
  end

  describe "get_subscribers/2" do
    test "when no subscribers are registered" do
      assert State.get_subscribers(:test_state, EventBus.Events.TestEvent) == []
    end

    test "when subscribers are registered" do
      State.add_subscriber(
        :test_state,
        EventBus.Events.TestEvent,
        EventBus.Subscribers.TestSubscriber1
      )

      assert State.get_subscribers(:test_state, EventBus.Events.TestEvent) == [
               EventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        EventBus.Events.TestEvent,
        EventBus.Subscribers.TestSubscriber2
      )

      assert State.get_subscribers(:test_state, EventBus.Events.TestEvent) == [
               EventBus.Subscribers.TestSubscriber2,
               EventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        EventBus.Events.TestEvent,
        EventBus.Subscribers.TestSubscriber2
      )

      assert State.get_subscribers(:test_state, EventBus.Events.TestEvent) == [
               EventBus.Subscribers.TestSubscriber2,
               EventBus.Subscribers.TestSubscriber1
             ]

      State.add_subscriber(
        :test_state,
        EventBus.Events.TestEvent,
        EventBus.Subscribers.TestSubscriber1
      )

      assert State.get_subscribers(:test_state, EventBus.Events.TestEvent) == [
               EventBus.Subscribers.TestSubscriber1,
               EventBus.Subscribers.TestSubscriber2
             ]
    end
  end
end
