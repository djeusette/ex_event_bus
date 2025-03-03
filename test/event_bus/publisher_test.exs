defmodule EventBus.PublisherTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: EventBus.TestEventBus.repo()

  alias Ecto.Adapters.SQL.Sandbox
  alias EventBus.OtherTestEventHandler
  alias EventBus.Publisher
  alias EventBus.TestEventBus
  alias EventBus.TestEventHandler

  setup tags do
    pid = Sandbox.start_owner!(EventBus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, _handler} = start_supervised({TestEventBus, []})
    :ok
  end

  describe "create_jobs/2" do
    test "with one subscriber, returns one job changeset" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: EventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: EventBus.TestEventHandler
                   },
                   queue: "event_bus",
                   worker: "EventBus.Worker"
                 }
               }
             ] = Publisher.create_job_changesets([TestEventHandler], event)
    end

    test "with multiple subscribers, returns job changesets" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: EventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: EventBus.OtherTestEventHandler
                   },
                   queue: "event_bus",
                   worker: "EventBus.Worker"
                 }
               },
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: EventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: EventBus.TestEventHandler
                   },
                   queue: "event_bus",
                   worker: "EventBus.Worker"
                 }
               }
             ] = Publisher.create_job_changesets([TestEventHandler, OtherTestEventHandler], event)
    end

    test "without subscribers, returns an empty list" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = Publisher.create_job_changesets([], event)
    end
  end

  describe "publish/3" do
    test "with no jobs, does nothing" do
      assert [] = Publisher.publish(TestEventBus.Oban, [])

      refute_enqueued(worker: EventBus.Worker)
    end

    test "with one job changeset, enqueues the job" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{} = job_changeset
             ] = Publisher.create_job_changesets([TestEventHandler], event)

      assert [
               %Oban.Job{
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 },
                 state: "available",
                 max_attempts: 20,
                 queue: "event_bus",
                 worker: "EventBus.Worker",
                 tags: ["eventbus"],
                 attempt: 0
               }
             ] = Publisher.publish(TestEventBus.Oban, [job_changeset])

      assert_enqueued(
        worker: EventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.EventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.EventBus.TestEventHandler",
          "metadata" => nil
        }
      )
    end

    test "with multiple job changesets, enqueues the jobs" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{} = job_changeset,
               %Ecto.Changeset{} = job_changeset2
             ] = Publisher.create_job_changesets([TestEventHandler, OtherTestEventHandler], event)

      assert [
               %Oban.Job{
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
                   "metadata" => nil
                 },
                 attempt: 0,
                 max_attempts: 20,
                 queue: "event_bus",
                 state: "available",
                 tags: ["eventbus"],
                 worker: "EventBus.Worker"
               },
               %Oban.Job{
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.EventBus.TestEventHandler",
                   "metadata" => nil
                 },
                 state: "available",
                 max_attempts: 20,
                 queue: "event_bus",
                 worker: "EventBus.Worker",
                 tags: ["eventbus"],
                 attempt: 0
               }
             ] = Publisher.publish(TestEventBus.Oban, [job_changeset, job_changeset2])

      assert_enqueued(
        worker: EventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.EventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.EventBus.TestEventHandler",
          "metadata" => nil
        }
      )

      assert_enqueued(
        worker: EventBus.Worker,
        args: %{
          "aggregate" => %{"name" => "John"},
          "changes" => %{"name" => "John"},
          "event" => "Elixir.EventBus.TestEvents.TestEvent",
          "event_handler" => "Elixir.EventBus.OtherTestEventHandler",
          "metadata" => nil
        }
      )
    end

    test "with a Multi transaction and one job, updates the multi" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{} = job_changeset
             ] = Publisher.create_job_changesets([TestEventHandler], event)

      multi = Ecto.Multi.new()

      assert %Ecto.Multi{
               operations: [{key, _}]
             } = Publisher.publish(TestEventBus.Oban, [job_changeset], multi: multi)

      assert :insert_event_bus_jobs = key

      refute_enqueued(worker: EventBus.Worker)
    end

    test "with a Multi transaction and multiple jobs, updates the multi" do
      event =
        struct(EventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{} = job_changeset,
               %Ecto.Changeset{} = job_changeset2
             ] = Publisher.create_job_changesets([TestEventHandler, OtherTestEventHandler], event)

      multi = Ecto.Multi.new()

      assert %Ecto.Multi{
               operations: [
                 {key, _}
               ]
             } =
               Publisher.publish(TestEventBus.Oban, [job_changeset, job_changeset2], multi: multi)

      assert :insert_event_bus_jobs = key

      refute_enqueued(worker: EventBus.Worker)
    end

    test "with a Multi transaction and no jobs, does not update the multi" do
      multi = Ecto.Multi.new()

      assert ^multi =
               Publisher.publish(TestEventBus.Oban, [], multi: multi)

      refute_enqueued(worker: EventBus.Worker)
    end
  end
end
