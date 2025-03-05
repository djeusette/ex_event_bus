defmodule ExEventBus.TestingTest do
  use ExUnit.Case, async: false
  use ExEventBus.Testing, ex_event_bus: ExEventBus.TestEventBus

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.OtherTestEventHandler
  alias ExEventBus.TestEventBus
  alias ExEventBus.TestEventHandler
  alias ExEventBus.TestEvents

  setup tags do
    pid = Sandbox.start_owner!(ExEventBus.Repo, shared: not tags[:async])
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
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_event_received(ExEventBus.TestEvents.TestEvent)
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
        assert_event_received(ExEventBus.TestEvents.TestEvent)
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
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_event_received(ExEventBus.TestEvents.TestEvent,
        args: %{event_handler: ExEventBus.OtherTestEventHandler}
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
        assert_event_received(ExEventBus.TestEvents.TestEvent,
          args: %{event_handler: ExEventBus.OtherTestEventHandler}
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

      refute_event_received(ExEventBus.TestEvents.TestEvent)
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
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        refute_event_received(ExEventBus.TestEvents.TestEvent)
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

      refute_event_received(ExEventBus.TestEvents.TestEvent,
        args: %{event_handler: ExEventBus.OtherTestEventHandler}
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
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_raise ExUnit.AssertionError, fn ->
        refute_event_received(ExEventBus.TestEvents.TestEvent,
          args: %{event_handler: ExEventBus.OtherTestEventHandler}
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
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert %{discard: 0, cancelled: 0, success: 2, failure: 0, snoozed: 0} = execute_events()
    end

    test "raises when an unhandled error occurs" do
      event =
        struct(TestEvents.RaiseEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.RaiseEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish(event)

      assert_raise RuntimeError, "RaiseEvent", fn -> execute_events() end
    end
  end
end
