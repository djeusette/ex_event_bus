defmodule EventBus.WorkerTest do
  use ExUnit.Case, async: false
  use EventBus.Event
  use Oban.Testing, repo: EventBus.TestEventBus.repo()

  alias Ecto.Adapters.SQL.Sandbox
  alias EventBus.TestEvents
  alias EventBus.Worker

  setup tags do
    pid = Sandbox.start_owner!(EventBus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  describe "perform/1" do
    test "executes the event handler for the given event" do
      event =
        struct(TestEvents.TestEvent, %{
          aggregate: %{name: "John"},
          changes: %{name: "John"}
        })
        |> JSON.encode!()
        |> JSON.decode!()

      assert {:ok, %TestEvents.TestEvent{} = returned_event} =
               Worker.perform(%Oban.Job{
                 inserted_at: DateTime.utc_now(),
                 attempt: 2,
                 args: %{
                   "event" => "Elixir.EventBus.TestEvents.TestEvent",
                   "aggregate" => Map.get(event, "aggregate"),
                   "changes" => Map.get(event, "changes"),
                   "metadata" => Map.get(event, "metadata"),
                   "event_handler" => "Elixir.EventBus.TestEventHandler"
                 }
               })

      assert is_event(returned_event)

      assert %{"inserted_at" => _, "attempt" => 2, "max_attempts" => 20} = returned_event.metadata
    end
  end
end
