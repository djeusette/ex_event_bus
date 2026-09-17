defmodule ExEventBus.StateTest do
  use ExUnit.Case, async: true

  alias ExEventBus.State

  defmodule Events.TestEvent do
  end

  defmodule Events.OtherTestEvent do
  end

  defmodule Subscribers.TestSubscriber1 do
  end

  defmodule Subscribers.TestSubscriber2 do
  end

  setup do
    State.clear(:test_state)
    State.clear(:other_test_state)
    :ok
  end

  describe "add_subscriber/3" do
    test "registers the subscriber for the given event only" do
      assert :ok =
               State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)

      assert State.get_subscribers(:test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber1
             ]

      assert State.get_subscribers(:test_state, Events.OtherTestEvent) == []
      assert State.get_subscribers(:test_state, Subscribers.TestSubscriber1) == []
    end

    test "when the subscriber is already registered, keeps a single entry" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)

      assert State.get_subscribers(:test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber1
             ]
    end

    test "when the subscriber is registered again, moves it to the front" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber2)
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)

      assert State.get_subscribers(:test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber1,
               Subscribers.TestSubscriber2
             ]
    end

    test "registers the subscriber on the given bus only" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)

      assert State.get_subscribers(:other_test_state, Events.TestEvent) == []
    end

    test "when the registering process exits, keeps the subscription" do
      registration =
        Task.async(fn ->
          State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
        end)

      assert :ok = Task.await(registration)
      refute Process.alive?(registration.pid)

      assert State.get_subscribers(:test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber1
             ]
    end
  end

  describe "get_subscribers/2" do
    test "when no subscriber is registered, returns an empty list" do
      assert State.get_subscribers(:test_state, Events.TestEvent) == []
    end

    test "when subscribers are registered, returns them most recently registered first" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber2)

      assert State.get_subscribers(:test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber2,
               Subscribers.TestSubscriber1
             ]
    end
  end

  describe "clear/1" do
    test "removes every subscription registered on the bus" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
      State.add_subscriber(:test_state, Events.OtherTestEvent, Subscribers.TestSubscriber2)

      assert :ok = State.clear(:test_state)

      assert State.get_subscribers(:test_state, Events.TestEvent) == []
      assert State.get_subscribers(:test_state, Events.OtherTestEvent) == []
    end

    test "leaves the subscriptions of other buses untouched" do
      State.add_subscriber(:test_state, Events.TestEvent, Subscribers.TestSubscriber1)
      State.add_subscriber(:other_test_state, Events.TestEvent, Subscribers.TestSubscriber2)

      State.clear(:test_state)

      assert State.get_subscribers(:other_test_state, Events.TestEvent) == [
               Subscribers.TestSubscriber2
             ]
    end

    test "when nothing is registered, returns :ok" do
      assert :ok = State.clear(:test_state)
    end
  end
end
