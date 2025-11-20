defmodule ExEventBus.InitialDataIntegrationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.IntegrationTestEventHandler
  alias ExEventBus.IntegrationTestEvents.UserCreated
  alias ExEventBus.IntegrationTestEvents.UserDeleted
  alias ExEventBus.IntegrationTestEvents.UserUpdated
  alias ExEventBus.IntegrationTestUser, as: TestUser
  alias ExEventBus.Repo
  alias ExEventBus.TestEventBus

  setup _tags do
    :ok = Sandbox.checkout(Repo)

    {:ok, _handler} = start_supervised({TestEventBus, []})
    {:ok, _handler} = start_supervised({IntegrationTestEventHandler, [event_bus: TestEventBus]})

    :ok
  end

  describe "INSERT operation" do
    test "real Ecto insert publishes event with nil initial_data for new fields" do
      changeset =
        TestUser.changeset(%TestUser{}, %{
          name: "John",
          email: "john@example.com",
          age: 30
        })

      {:ok, user} = Repo.insert(changeset, success_event: UserCreated)

      assert user.name == "John"
      assert user.email == "john@example.com"
      assert user.age == 30

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

    test "insert with partial fields publishes event with nil for those fields" do
      changeset =
        TestUser.changeset(%TestUser{}, %{
          name: "Jane",
          email: "jane@example.com"
        })

      {:ok, user} = Repo.insert(changeset, success_event: UserCreated)

      assert user.name == "Jane"
      assert user.email == "jane@example.com"
      assert user.age == nil

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
    test "real Ecto update publishes event with old values in initial_data" do
      # Insert user first
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "old@example.com",
            age: 30
          })
        )

      # Update only email
      changeset = TestUser.changeset(user, %{email: "new@example.com"})
      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      assert updated.email == "new@example.com"
      assert updated.name == "John"
      assert updated.age == 30

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
      # Insert user first
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "old@example.com",
            age: 30
          })
        )

      # Update email and age
      changeset = TestUser.changeset(user, %{email: "new@example.com", age: 35})
      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      assert updated.email == "new@example.com"
      assert updated.age == 35

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

    test "update with no changes does not publish event" do
      # Insert user first
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "john@example.com",
            age: 30
          })
        )

      # Update with same values (no actual changes)
      changeset = TestUser.changeset(user, %{})
      {:ok, _updated} = Repo.update(changeset, success_event: UserUpdated)

      refute_enqueued(worker: ExEventBus.Worker)
    end

    test "update field from value to nil" do
      # Insert user with age
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "john@example.com",
            age: 30
          })
        )

      # Update age to nil
      changeset = TestUser.changeset(user, %{age: nil})
      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      assert updated.age == nil

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
      # Insert user without age
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "john@example.com"
          })
        )

      # Update age from nil to a value
      changeset = TestUser.changeset(user, %{age: 25})
      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      assert updated.age == 25

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
    test "real Ecto delete publishes event with empty initial_data" do
      # Insert user first
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "John",
            email: "john@example.com",
            age: 30
          })
        )

      # Delete user
      {:ok, deleted} = Repo.delete(user, success_event: UserDeleted)

      assert deleted.name == "John"

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserDeleted",
          "changes" => %{},
          "initial_data" => %{}
        }
      )
    end

    test "delete with changeset publishes event with empty initial_data" do
      # Insert user first
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "Jane",
            email: "jane@example.com",
            age: 25
          })
        )

      # Delete user with changeset
      changeset = Ecto.Changeset.change(user)
      {:ok, deleted} = Repo.delete(changeset, success_event: UserDeleted)

      assert deleted.name == "Jane"

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
