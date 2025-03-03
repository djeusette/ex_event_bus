defmodule ExEventBus.PublisherTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.TestEventBus.repo()

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.OtherTestEventHandler
  alias ExEventBus.Publisher
  alias ExEventBus.TestEventBus
  alias ExEventBus.TestEventHandler

  setup tags do
    pid = Sandbox.start_owner!(ExEventBus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, _handler} = start_supervised({TestEventBus, []})
    :ok
  end

  describe "create_jobs/2" do
    test "with one subscriber, returns one job changeset" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: ExEventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: ExEventBus.TestEventHandler
                   },
                   queue: "ex_event_bus",
                   worker: "ExEventBus.Worker"
                 }
               }
             ] = Publisher.create_job_changesets([TestEventHandler], event)
    end

    test "with multiple subscribers, returns job changesets" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: ExEventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: ExEventBus.OtherTestEventHandler
                   },
                   queue: "ex_event_bus",
                   worker: "ExEventBus.Worker"
                 }
               },
               %Ecto.Changeset{
                 changes: %{
                   args: %{
                     metadata: nil,
                     aggregate: %{name: "John"},
                     event: ExEventBus.TestEvents.TestEvent,
                     changes: %{name: "John"},
                     event_handler: ExEventBus.TestEventHandler
                   },
                   queue: "ex_event_bus",
                   worker: "ExEventBus.Worker"
                 }
               }
             ] = Publisher.create_job_changesets([TestEventHandler, OtherTestEventHandler], event)
    end

    test "without subscribers, returns an empty list" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })

      assert [] = Publisher.create_job_changesets([], event)
    end
  end

  describe "publish/3" do
    test "with no jobs, does nothing" do
      assert [] = Publisher.publish(TestEventBus.Oban, [])

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "with one job changeset, enqueues the job" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
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
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 },
                 state: "available",
                 max_attempts: 20,
                 queue: "ex_event_bus",
                 worker: "ExEventBus.Worker",
                 tags: ["ex_event_bus"],
                 attempt: 0
               }
             ] = Publisher.publish(TestEventBus.Oban, [job_changeset])

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
    end

    test "with multiple job changesets, enqueues the jobs" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
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
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.OtherTestEventHandler",
                   "metadata" => nil
                 },
                 attempt: 0,
                 max_attempts: 20,
                 queue: "ex_event_bus",
                 state: "available",
                 tags: ["ex_event_bus"],
                 worker: "ExEventBus.Worker"
               },
               %Oban.Job{
                 args: %{
                   "aggregate" => %{"name" => "John"},
                   "changes" => %{"name" => "John"},
                   "event" => "Elixir.ExEventBus.TestEvents.TestEvent",
                   "event_handler" => "Elixir.ExEventBus.TestEventHandler",
                   "metadata" => nil
                 },
                 state: "available",
                 max_attempts: 20,
                 queue: "ex_event_bus",
                 worker: "ExEventBus.Worker",
                 tags: ["ex_event_bus"],
                 attempt: 0
               }
             ] = Publisher.publish(TestEventBus.Oban, [job_changeset, job_changeset2])

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

    test "with a Multi transaction and one job, updates the multi" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
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

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "with a Multi transaction and multiple jobs, updates the multi" do
      event =
        struct(ExEventBus.TestEvents.TestEvent, %{
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

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "with a Multi transaction and no jobs, does not update the multi" do
      multi = Ecto.Multi.new()

      assert ^multi =
               Publisher.publish(TestEventBus.Oban, [], multi: multi)

      refute_enqueued(worker: ExEventBus.Worker)
    end
  end
end
