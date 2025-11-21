defmodule ExEventBus.InitialDataIntegrationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: ExEventBus.Repo

  alias Ecto.Adapters.SQL.Sandbox
  alias ExEventBus.IntegrationTestEventHandler
  alias ExEventBus.IntegrationTestEvents.UserCreated
  alias ExEventBus.IntegrationTestEvents.UserDeleted
  alias ExEventBus.IntegrationTestEvents.UserUpdated
  alias ExEventBus.Repo
  alias ExEventBus.Schemas.User, as: TestUser
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
            "id" => user.id,
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
            "id" => user.id,
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

    test "insert with nested associations via cast_assoc includes association changes" do
      changeset =
        TestUser.changeset(%TestUser{}, %{
          name: "Alice",
          email: "alice@example.com",
          age: 28,
          profile: %{bio: "Software Engineer", avatar_url: "https://example.com/avatar.jpg"},
          posts: [
            %{title: "First Post", body: "Hello World"},
            %{title: "Second Post", body: "Elixir is great"}
          ]
        })

      {:ok, user} = Repo.insert(changeset, success_event: UserCreated)

      assert user.name == "Alice"
      user_with_assocs = Repo.preload(user, [:profile, :posts])
      assert user_with_assocs.profile.bio == "Software Engineer"
      assert length(user_with_assocs.posts) == 2

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserCreated",
          "changes" => %{
            "name" => "Alice",
            "email" => "alice@example.com",
            "age" => 28,
            "profile" => %{
              "id" => nil,
              "bio" => "Software Engineer",
              "avatar_url" => "https://example.com/avatar.jpg"
            },
            "posts" => [
              %{"id" => nil, "title" => "First Post", "body" => "Hello World"},
              %{"id" => nil, "title" => "Second Post", "body" => "Elixir is great"}
            ]
          },
          "initial_data" => %{
            "name" => nil,
            "email" => nil,
            "age" => nil,
            "profile" => nil,
            "posts" => []
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

    test "update with nested associations via cast_assoc includes association changes" do
      # Insert user with profile and posts
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "Bob",
            email: "bob@example.com",
            age: 30,
            profile: %{bio: "Developer", avatar_url: "https://example.com/bob.jpg"},
            posts: [%{title: "Original Post", body: "Original content"}]
          })
        )

      # Load associations for comparison
      user_with_assocs = Repo.preload(user, [:profile, :posts])
      original_profile = user_with_assocs.profile
      original_post = List.first(user_with_assocs.posts)

      # Update profile bio and add a new post
      changeset =
        TestUser.changeset(user_with_assocs, %{
          profile: %{id: original_profile.id, bio: "Senior Developer"},
          posts: [
            %{id: original_post.id, title: "Updated Post"},
            %{title: "New Post", body: "New content"}
          ]
        })

      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      updated_with_assocs = Repo.preload(updated, [:profile, :posts], force: true)
      assert updated_with_assocs.profile.bio == "Senior Developer"
      assert length(updated_with_assocs.posts) == 2

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "profile" => %{"id" => original_profile.id, "bio" => "Senior Developer"},
            "posts" => [
              %{"id" => original_post.id, "title" => "Updated Post"},
              %{"id" => nil, "title" => "New Post", "body" => "New content"}
            ]
          },
          "initial_data" => %{
            "profile" => %{
              "id" => original_profile.id,
              "bio" => original_profile.bio
            },
            "posts" => [
              %{
                "id" => original_post.id,
                "title" => original_post.title
              }
            ]
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

    test "delete user with associations publishes event with empty changes and initial_data" do
      # Insert user with profile and posts
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "Charlie",
            email: "charlie@example.com",
            age: 35,
            profile: %{bio: "Manager", avatar_url: "https://example.com/charlie.jpg"},
            posts: [
              %{title: "Post 1", body: "Content 1"},
              %{title: "Post 2", body: "Content 2"}
            ]
          })
        )

      # Verify associations were created
      user_with_assocs = Repo.preload(user, [:profile, :posts])
      assert user_with_assocs.profile != nil
      assert length(user_with_assocs.posts) == 2

      # Delete user
      {:ok, deleted} = Repo.delete(user, success_event: UserDeleted)

      assert deleted.name == "Charlie"

      # DELETE operations always have empty changes and initial_data
      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserDeleted",
          "changes" => %{},
          "initial_data" => %{}
        }
      )
    end

    test "delete with changeset when user has associations publishes event with empty data" do
      # Insert user with profile and posts
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "Diana",
            email: "diana@example.com",
            age: 28,
            profile: %{bio: "Designer", avatar_url: "https://example.com/diana.jpg"},
            posts: [%{title: "Design Post", body: "Design content"}]
          })
        )

      # Verify associations were created
      user_with_assocs = Repo.preload(user, [:profile, :posts])
      assert user_with_assocs.profile != nil
      assert length(user_with_assocs.posts) == 1

      # Delete user with changeset
      changeset = Ecto.Changeset.change(user)
      {:ok, deleted} = Repo.delete(changeset, success_event: UserDeleted)

      assert deleted.name == "Diana"

      # DELETE operations with changeset also have empty changes and initial_data
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

  describe "Composite Primary Keys - nested associations" do
    test "insert with nested composite PK includes all PK fields" do
      changeset =
        TestUser.changeset(%TestUser{}, %{
          name: "Alice",
          email: "alice@example.com",
          permissions: [
            %{user_id: nil, resource_id: 10, permission_level: "read"},
            %{user_id: nil, resource_id: 20, permission_level: "write"}
          ]
        })

      {:ok, user} = Repo.insert(changeset, success_event: UserCreated)

      user_with_perms = Repo.preload(user, :permissions)
      assert length(user_with_perms.permissions) == 2

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserCreated",
          "changes" => %{
            "name" => "Alice",
            "email" => "alice@example.com",
            "permissions" => [
              %{
                "user_id" => nil,
                "resource_id" => nil,
                "permission_level" => "read"
              },
              %{
                "user_id" => nil,
                "resource_id" => nil,
                "permission_level" => "write"
              }
            ]
          },
          "initial_data" => %{
            "name" => nil,
            "email" => nil,
            "permissions" => []
          }
        }
      )
    end

    test "update with nested composite PK includes all PK fields" do
      # Insert user with permissions
      {:ok, user} =
        Repo.insert(
          TestUser.changeset(%TestUser{}, %{
            name: "Bob",
            email: "bob@example.com",
            permissions: [
              %{user_id: nil, resource_id: 10, permission_level: "read"}
            ]
          })
        )

      user_with_perms = Repo.preload(user, :permissions)
      existing_perm = List.first(user_with_perms.permissions)

      # Update: modify existing permission and add new one
      changeset =
        TestUser.changeset(user_with_perms, %{
          permissions: [
            %{
              user_id: existing_perm.user_id,
              resource_id: existing_perm.resource_id,
              permission_level: "write"
            },
            %{user_id: nil, resource_id: 20, permission_level: "admin"}
          ]
        })

      {:ok, updated} = Repo.update(changeset, success_event: UserUpdated)

      updated_with_perms = Repo.preload(updated, :permissions, force: true)
      assert length(updated_with_perms.permissions) == 2

      assert_enqueued(
        worker: ExEventBus.Worker,
        args: %{
          "event" => "Elixir.ExEventBus.IntegrationTestEvents.UserUpdated",
          "changes" => %{
            "permissions" => [
              %{
                "user_id" => existing_perm.user_id,
                "resource_id" => existing_perm.resource_id,
                "permission_level" => "write"
              },
              %{
                "user_id" => nil,
                "resource_id" => nil,
                "permission_level" => "admin"
              }
            ]
          },
          "initial_data" => %{
            "permissions" => [
              %{
                "user_id" => existing_perm.user_id,
                "resource_id" => existing_perm.resource_id,
                "permission_level" => "read"
              }
            ]
          }
        }
      )
    end
  end
end
