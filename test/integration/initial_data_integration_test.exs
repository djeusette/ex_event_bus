defmodule ExEventBus.InitialDataIntegrationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.TestEventBus.repo()

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.IntegrationTestEventHandler
  alias ExEventBus.IntegrationTestEvents.UserCreated
  alias ExEventBus.IntegrationTestEvents.UserDeleted
  alias ExEventBus.IntegrationTestEvents.UserUpdated
  alias ExEventBus.IntegrationTestUser, as: TestUser
  alias ExEventBus.Repo
  alias ExEventBus.TestEventBus

  setup tags do
    pid = Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    {:ok, _handler} = start_supervised({TestEventBus, []})
    {:ok, _handler} = start_supervised({IntegrationTestEventHandler, [event_bus: TestEventBus]})

    :ok
  end

  describe "INSERT operation" do
    test "publishes event with nil initial_data for new fields" do
      user = %TestUser{id: 1, name: "John", email: "john@example.com", age: 30}

      event =
        struct(UserCreated, %{
          aggregate: user,
          changes: %{name: "John", email: "john@example.com", age: 30},
          initial_data: %{name: nil, email: nil, age: nil},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserCreated",
          "changes" => %{
            "name" => "John",
            "email" => "john@example.com",
            "age" => 30
          },
          "initial_data" => %{
            "name" => nil,
            "email" => nil,
            "age" => nil
          }
        }
      )
    end

    test "publishes event with partial fields and nil initial_data" do
      user = %TestUser{id: 2, name: "Jane", email: "jane@example.com"}

      event =
        struct(UserCreated, %{
          aggregate: user,
          changes: %{name: "Jane", email: "jane@example.com"},
          initial_data: %{name: nil, email: nil},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserCreated",
          "changes" => %{
            "name" => "Jane",
            "email" => "jane@example.com"
          },
          "initial_data" => %{
            "name" => nil,
            "email" => nil
          }
        }
      )
    end
  end

  describe "UPDATE operation" do
    test "publishes event with old values in initial_data" do
      user = %TestUser{id: 3, name: "John", email: "new@example.com", age: 30}

      event =
        struct(UserUpdated, %{
          aggregate: user,
          changes: %{email: "new@example.com"},
          initial_data: %{email: "old@example.com"},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "email" => "new@example.com"
          },
          "initial_data" => %{
            "email" => "old@example.com"
          }
        }
      )
    end

    test "update multiple fields includes all old values in initial_data" do
      user = %TestUser{id: 4, name: "John", email: "new@example.com", age: 35}

      event =
        struct(UserUpdated, %{
          aggregate: user,
          changes: %{email: "new@example.com", age: 35},
          initial_data: %{email: "old@example.com", age: 30},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "email" => "new@example.com",
            "age" => 35
          },
          "initial_data" => %{
            "email" => "old@example.com",
            "age" => 30
          }
        }
      )
    end

    test "update field from value to nil" do
      user = %TestUser{id: 5, name: "John", email: "john@example.com", age: nil}

      event =
        struct(UserUpdated, %{
          aggregate: user,
          changes: %{age: nil},
          initial_data: %{age: 30},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "age" => nil
          },
          "initial_data" => %{
            "age" => 30
          }
        }
      )
    end

    test "update field from nil to value" do
      user = %TestUser{id: 6, name: "John", email: "john@example.com", age: 25}

      event =
        struct(UserUpdated, %{
          aggregate: user,
          changes: %{age: 25},
          initial_data: %{age: nil},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "age" => 25
          },
          "initial_data" => %{
            "age" => nil
          }
        }
      )
    end
  end

  describe "DELETE operation" do
    test "publishes event with empty initial_data" do
      user = %TestUser{id: 7, name: "John", email: "john@example.com", age: 30}

      event =
        struct(UserDeleted, %{
          aggregate: user,
          changes: %{},
          initial_data: %{},
          metadata: nil
        })

      TestEventBus.publish(event)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserDeleted",
          "changes" => %{},
          "initial_data" => %{}
        }
      )
    end
  end
end
