defmodule EventBus.TestingTest do
  use ExUnit.Case, async: false
  use EventBus.Testing, event_bus: EventBus.TestEventBus

  alias Ecto.Adapters.SQL.Sandbox
  alias EventBus.OtherTestEventHandler
  alias EventBus.TestEventBus
  alias EventBus.TestEventHandler
  alias EventBus.TestEvents

  setup tags do
    pid = Sandbox.start_owner!(EventBus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  setup do
    assert {:ok, _handler} = start_supervised(TestEventBus, [])

    :ok
  end

  describe "assert_event_received/1 when events are received" do
    setup do
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_event_received(EventBus.TestEvents.TestEvent)
    end
  end

  describe "assert_event_received/1 when no events are received" do
    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        assert_event_received(EventBus.TestEvents.TestEvent)
      end
    end
  end

  describe "assert_event_received/2 when events are received" do
    setup do
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_event_received(EventBus.TestEvents.TestEvent,
        args: %{event_handler: EventBus.OtherTestEventHandler}
      )
    end
  end

  describe "assert_event_received/2 when no events are received" do
    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        assert_event_received(EventBus.TestEvents.TestEvent,
          args: %{event_handler: EventBus.OtherTestEventHandler}
        )
      end
    end
  end

  describe "refute_event_received/1 when no events are received" do
    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = TestEventBus.publish(event)

      refute_event_received(EventBus.TestEvents.TestEvent)
    end
  end

  describe "refute_event_received/1 when events are received" do
    setup do
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        refute_event_received(EventBus.TestEvents.TestEvent)
      end
    end
  end

  describe "refute_event_received/2 when no events are received" do
    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = TestEventBus.publish(event)

      refute_event_received(EventBus.TestEvents.TestEvent,
        args: %{event_handler: EventBus.OtherTestEventHandler}
      )
    end
  end

  describe "refute_event_received/2 when events are received" do
    setup do
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "works as expected" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        refute_event_received(EventBus.TestEvents.TestEvent,
          args: %{event_handler: EventBus.OtherTestEventHandler}
        )
      end
    end
  end

  describe "execute_events/1" do
    setup do
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "execute the received events" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "EventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert %{discard: 0, cancelled: 0, success: 2, failure: 0, snoozed: 0} = execute_events()
    end
  end
end
