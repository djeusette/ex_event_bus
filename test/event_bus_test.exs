defmodule ExEventBusTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.TestEventBus.repo()

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.OtherTestEventHandler
  alias ExEventBus.TestEventBus
  alias ExEventBus.TestEventHandler
  alias ExEventBus.TestEvents

  setup tags do
    pid = Sandbox.start_owner!(ExEventBus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  def start_event_bus do
    start_supervised(TestEventBus, [])
  end

  test "starts" do
    assert {:ok, _handler} = start_event_bus()
  end

  describe "subscribe/2" do
    setup do
      assert {:ok, _handler} = start_event_bus()

      :ok
    end

    test "with event as atom, adds the subscriber to the subscriber list for the given event" do
      assert :ok = TestEventBus.subscribe(:event_module, :subscriber_module)
      assert :ok = TestEventBus.subscribe(TestEvents.TestEvent, :subscriber_module)
    end

    test "with event as string, adds the subscriber to the subscriber list for the given event" do
      assert :ok =
               TestEventBus.subscribe(
                 "Elixir.ExEventBus.TestEvents.TestEvent",
                 :subscriber_module
               )
    end
  end

  describe "subscribers/1" do
    setup do
      assert {:ok, _handler} = start_event_bus()
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "returns the subscribers to the given event struct" do
      event1 = struct(TestEvents.TestEvent, %{})
      event2 = struct(TestEvents.TestEvent2, %{})

      assert TestEventBus.subscribers(event2) == []
      assert TestEventBus.subscribers(event1) == [OtherTestEventHandler, TestEventHandler]
    end

    test "returns the subscribers to the given event module" do
      assert TestEventBus.subscribers(TestEvents.TestEvent2) == []

      assert TestEventBus.subscribers(TestEvents.TestEvent) == [
               OtherTestEventHandler,
               TestEventHandler
             ]
    end
  end

  describe "publish/1" do
    setup do
      assert {:ok, _handler} = start_event_bus()
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "publishes one event to its subscribers" do
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

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.TestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
          "metadata" => nil
        }
      )
    end

    test "publishes multiple events to their subscribers" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      event2 =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "Jane"},
          changes: %{name: "Jane"}
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
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "Jane"},
                   "changes" => %{"name" => "Jane"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 }
               },
               %Oban.Job{
                 worker: "ExEventBus.Worker",
                 args: %{
                   "aggregate" => %{"name" => "Jane"},
                   "changes" => %{"name" => "Jane"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 }
               }
             ] = TestEventBus.publish([event, event2])

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.TestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "Jane"},
          "changes" => %{"name" => "Jane"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.TestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "Jane"},
          "changes" => %{"name" => "Jane"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
          "metadata" => nil
        }
      )
    end

    test "when there are no subscribers" do
      event =
        struct(TestEvents.TestEvent2, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = TestEventBus.publish(event)

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "publishes an actual struct in the event" do
      aggregate =
        %ExEventBus.TestStruct{
          id: Ecto.UUID.generate(),
          name: "John",
          inserted_at: DateTime.utc_now()
        }

      event =
        struct(TestEvents.TestEvent, %{
          aggregate: aggregate,
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

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.TestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
          "metadata" => nil
        }
      )
    end
  end

  describe "publish/2" do
    setup do
      assert {:ok, _handler} = start_event_bus()
      assert {:ok, _handler} = start_supervised({TestEventHandler, [event_bus: TestEventBus]})

      assert {:ok, _handler} =
               start_supervised({OtherTestEventHandler, [event_bus: TestEventBus]})

      :ok
    end

    test "with one event, updates the multi" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      multi = Ecto.Multi.new()

      assert %Ecto.Multi{
               operations: [
                 {key, _}
               ]
             } = TestEventBus.publish(multi, event)

      assert :insert_event_bus_jobs = key

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "with multiple events, updates the multi" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      event2 =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "Jane"},
          changes: %{name: "Jane"}
        })

      multi = Ecto.Multi.new()

      assert %Ecto.Multi{
               operations: [
                 {key, _}
               ]
             } = TestEventBus.publish(multi, [event, event2])

      assert :insert_event_bus_jobs = key

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "when there are no subscribers to the event, does not update the multi" do
      event =
        struct(TestEvents.TestEvent2, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      multi = Ecto.Multi.new()

      assert ^multi = TestEventBus.publish(multi, event)

      refute_enqueued(worker: ExEventBus.Worker)
    end
  end

  describe "repo/0" do
    test "returns the repo used by Oban" do
      assert TestEventBus.repo() == ExEventBus.Repo
    end
  end
end
