defmodule ExEventBus.EctoRepoWrapperIntegrationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.IntegrationTestEventHandler
  alias ExEventBus.IntegrationTestEvents.{UserCreated, UserDeleted, UserUpdated}
  alias ExEventBus.Repo
  alias ExEventBus.Restart
  alias ExEventBus.Schemas.User
  alias ExEventBus.TestEventBus

  @user_created "Elixir.ExEventBus.IntegrationTestEvents.UserCreated"
  @user_deleted "Elixir.ExEventBus.IntegrationTestEvents.UserDeleted"
  @user_updated "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated"
  @integration_handler "Elixir.ExEventBus.IntegrationTestEventHandler"

  setup do
    :ok = Sandbox.checkout(Repo)

    TestEventBus.clear_subscribers()
    {:ok, _bus} = start_supervised({TestEventBus, []})
    {:ok, _handler} = start_supervised({IntegrationTestEventHandler, [event_bus: TestEventBus]})

    :ok
  end

  defp new_user, do: %User{name: "John", email: "john@example.com", age: 30}

  describe "insert/2 with a plain struct" do
    test "inserts the struct" do
      assert {:ok, %User{id: id, name: "John"}} = Repo.insert(new_user())
      assert %User{name: "John"} = Repo.get!(User, id)
    end

    test "publishes the success event with empty changes and initial_data" do
      assert {:ok, %User{}} = Repo.insert(new_user(), success_event: UserCreated)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{"event" => @user_created, "changes" => %{}, "initial_data" => %{}}
      )
    end
  end

  describe "insert!/2 with a plain struct" do
    test "inserts the struct" do
      assert %User{id: id, name: "John"} = Repo.insert!(new_user())
      assert %User{name: "John"} = Repo.get!(User, id)
    end
  end

  describe "delete/2 with a plain struct" do
    test "deletes the struct" do
      user = Repo.insert!(new_user())

      assert {:ok, %User{name: "John"}} = Repo.delete(user)
      assert Repo.get(User, user.id) == nil
    end

    test "publishes the success event with empty changes and initial_data" do
      user = Repo.insert!(new_user())

      assert {:ok, %User{}} = Repo.delete(user, success_event: UserDeleted)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{"event" => @user_deleted, "changes" => %{}, "initial_data" => %{}}
      )
    end
  end

  describe "delete!/2 with a plain struct" do
    test "deletes the struct" do
      user = Repo.insert!(new_user())

      assert %User{name: "John"} = Repo.delete!(user)
      assert Repo.get(User, user.id) == nil
    end
  end

  describe "update/2 with a changeset" do
    test "publishes the success event with the changes" do
      user = Repo.insert!(new_user())

      assert {:ok, %User{name: "Jane"}} =
               user
               |> User.changeset(%{name: "Jane"})
               |> Repo.update(success_event: UserUpdated)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => @user_updated,
          "event_handler" => @integration_handler,
          "changes" => %{"name" => "Jane"}
        }
      )
    end

    test "when the bus crashed and restarted, still publishes the success event" do
      user = Repo.insert!(new_user())

      Restart.crash_and_await(TestEventBus)

      assert {:ok, %User{name: "Jane"}} =
               user
               |> User.changeset(%{name: "Jane"})
               |> Repo.update(success_event: UserUpdated)

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => @user_updated,
          "event_handler" => @integration_handler,
          "changes" => %{"name" => "Jane"}
        }
      )
    end
  end

  describe "changeset-only functions with a plain struct" do
    for fun <- [:update, :update!, :insert_or_update, :insert_or_update!] do
      test "#{fun}/2 raises FunctionClauseError from the repo's changeset clause" do
        user = Repo.insert!(new_user())

        assert %FunctionClauseError{module: Repo, function: unquote(fun), arity: 2} =
                 assert_raise(FunctionClauseError, fn -> call_repo(unquote(fun), user) end)
      end
    end
  end

  describe "struct-or-changeset functions with a non-struct" do
    for fun <- [:insert, :insert!, :delete, :delete!] do
      test "#{fun}/2 raises FunctionClauseError from the repo's struct clause" do
        assert %FunctionClauseError{module: Repo, function: unquote(fun), arity: 2} =
                 assert_raise(FunctionClauseError, fn ->
                   call_repo(unquote(fun), %{name: "John"})
                 end)
      end
    end
  end

  # Dispatches dynamically so the type checker does not flag the intentional
  # misuse at compile time: it knows what these functions accept.
  defp call_repo(fun, arg), do: apply(Repo, fun, [arg])
end
