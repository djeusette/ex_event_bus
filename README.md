# ExEventBus

ExEventBus provides an event bus that uses the outbox pattern.  Behind the scenes, 
it relies on Oban and ConCache.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_event_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_event_bus, "~> 0.2.0"}
  ]
end
```

## Run tests

```bash
# run only once to setup the test DB
MIX_ENV=test mix test.setup

# actually run the tests
mix test
```

## Setup

1. Create a module that defines your event bus

  ```elixir
  defmodule MyApp.EventBus do
    use ExEventBus, otp_app: :my_app
  end
  ```

2. Add the required config for your EventBus, that is the Oban config

  ```elixir 
  config :my_app, MyApp.EventBus,
    oban: [
      engine: Oban.Engines.Basic,
      notifier: Oban.Notifiers.Postgres,
      repo: MyApp.Repo,
      plugins: [
        {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(60)},
        {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7}
      ],
      queues: [
        event_bus: 2
      ]
    ]
  ```

3. Create your first events 

  ```elixir 
  defmodule MyApp.Events do
    use ExEventBus.Event

    defevent(MyEvent)
  end
  ```

4. Create your first event handler

  ```elixir
  defmodule MyApp.EventHandler do
    use ExEventBus.EventHandler,
      event_bus: MyApp.EventBus,
      events: [MyApp.Events.MyEvent]

    @impl ExEventBus.EventHandler
    def handle_event(%MyApp.Events.MyEvent{aggregate: %{"id" => aggregate_id}}) do
      # ... handle the event here
    end
  end
  ```

5. Add your event bus to your supervision tree

  ```elixir
  # add the event bus to your application children 

  def start(_type, _args) do 
    # ... 

    children = [
      # ...
      MyApp.EventBus,
      # ...
    ]

    # ...
  ```

6. Add your event handlers to your supervision tree

  ```elixir
  def start(_type, _args) do
    # ...

    children = [
      # ...
      {MyApp.EventHandler, [event_bus: MyApp.EventBus]},
      # ...
    ]

    # ...
  end
  ```

## Event Structure

Events published by ExEventBus contain detailed information about the operation that triggered them. Each event includes:

- **`aggregate`**: The complete struct of the affected entity
- **`changes`**: Map of fields that changed (with primary keys for associations)
- **`initial_data`**: Map of previous values for changed fields
- **`metadata`**: Optional metadata passed to the operation

### Changes and Initial Data

The `changes` and `initial_data` maps provide a complete picture of what changed:

```elixir
# For a simple update
%MyEvent{
  aggregate: %User{id: 1, name: "Jane Doe", email: "jane@example.com"},
  changes: %{"email" => "jane.doe@example.com"},
  initial_data: %{"email" => "jane@example.com"},
  metadata: nil
}
```

#### INSERT Operations

For insertions, `initial_data` contains `nil` values for the fields being set:

```elixir
%UserCreated{
  aggregate: %User{id: 1, name: "John", email: "john@example.com"},
  changes: %{
    "name" => "John",
    "email" => "john@example.com"
  },
  initial_data: %{
    "name" => nil,
    "email" => nil
  }
}
```

#### UPDATE Operations

For updates, `initial_data` contains only the old values of fields that actually changed:

```elixir
%UserUpdated{
  aggregate: %User{id: 1, name: "John", email: "new@example.com", age: 30},
  changes: %{
    "email" => "new@example.com",
    "age" => 30
  },
  initial_data: %{
    "email" => "old@example.com",
    "age" => 25
  }
}
```

#### DELETE Operations

For deletions, both `changes` and `initial_data` are empty:

```elixir
%UserDeleted{
  aggregate: %User{id: 1, name: "John", email: "john@example.com"},
  changes: %{},
  initial_data: %{}
}
```

## Association Change Tracking

ExEventBus provides detailed tracking of association changes when using `Ecto.Changeset.cast_assoc/3`. This allows you to distinguish between creates, updates, and deletes within nested associations.

### Primary Keys in Associations

**All nested associations include their primary key** in both `changes` and `initial_data` to distinguish between creates, updates, and deletes:

#### Create (New Item)
```elixir
changes: %{
  "profile" => %{
    "id" => nil,  # ← nil indicates CREATE
    "bio" => "Engineer"
  }
}

initial_data: %{
  "profile" => nil  # ← nil because association didn't exist
}
```

#### Update (Existing Item)
```elixir
changes: %{
  "profile" => %{
    "id" => 5,  # ← value indicates UPDATE
    "bio" => "Senior Engineer"
  }
}

initial_data: %{
  "profile" => %{
    "id" => 5,  # ← same ID
    "bio" => "Engineer"  # ← old value
  }
}
```

#### Delete (Removed Item)
```elixir
# For has_many: item present in initial_data but absent from changes
changes: %{
  "posts" => [
    %{"id" => 1, "title" => "Kept Post"}
  ]
}

initial_data: %{
  "posts" => [
    %{"id" => 1, "title" => "Kept Post"},
    %{"id" => 2, "title" => "Deleted Post"}  # ← Post 2 deleted
  ]
}
```

**Summary:**
- **New items**: `"id" => nil` in `changes`, association is `nil` or `[]` in `initial_data`
- **Updated items**: `"id" => <value>` in both `changes` and `initial_data`
- **Deleted items**: Present in `initial_data` but absent from `changes`

### Has One Associations

#### Creating a Profile

```elixir
# Ecto operation
user_changeset = User.changeset(%User{}, %{
  name: "Alice",
  email: "alice@example.com",
  profile: %{bio: "Software Engineer", avatar_url: "https://example.com/avatar.jpg"}
})

Repo.insert(user_changeset, success_event: UserCreated)

# Published event
%UserCreated{
  changes: %{
    "name" => "Alice",
    "email" => "alice@example.com",
    "profile" => %{
      "id" => nil,  # ← nil indicates this is a CREATE
      "bio" => "Software Engineer",
      "avatar_url" => "https://example.com/avatar.jpg"
    }
  },
  initial_data: %{
    "name" => nil,
    "email" => nil,
    "profile" => nil  # ← nil because association didn't exist
  }
}
```

#### Updating a Profile

```elixir
# Ecto operation
user = Repo.get(User, 1) |> Repo.preload(:profile)

user_changeset = User.changeset(user, %{
  profile: %{id: user.profile.id, bio: "Senior Software Engineer"}
})

Repo.update(user_changeset, success_event: UserUpdated)

# Published event
%UserUpdated{
  changes: %{
    "profile" => %{
      "id" => 5,  # ← ID present indicates this is an UPDATE
      "bio" => "Senior Software Engineer"
    }
  },
  initial_data: %{
    "profile" => %{
      "id" => 5,  # ← Same ID
      "bio" => "Software Engineer"  # ← Only changed field (not avatar_url)
    }
  }
}
```

### Has Many Associations

#### Creating Posts

```elixir
# Ecto operation
user_changeset = User.changeset(%User{}, %{
  name: "Bob",
  email: "bob@example.com",
  posts: [
    %{title: "First Post", body: "Hello World"},
    %{title: "Second Post", body: "Elixir is great"}
  ]
})

Repo.insert(user_changeset, success_event: UserCreated)

# Published event
%UserCreated{
  changes: %{
    "name" => "Bob",
    "email" => "bob@example.com",
    "posts" => [
      %{"id" => nil, "title" => "First Post", "body" => "Hello World"},
      %{"id" => nil, "title" => "Second Post", "body" => "Elixir is great"}
    ]
  },
  initial_data: %{
    "name" => nil,
    "email" => nil,
    "posts" => []  # ← Empty list because no posts existed
  }
}
```

#### Mixed Operations (Update + Create)

```elixir
# Ecto operation
user = Repo.get(User, 1) |> Repo.preload(:posts)
# Assume user has one existing post with id: 10

user_changeset = User.changeset(user, %{
  posts: [
    %{id: 10, title: "Updated Title"},  # Update existing
    %{title: "New Post", body: "New Content"}  # Create new
  ]
})

Repo.update(user_changeset, success_event: UserUpdated)

# Published event
%UserUpdated{
  changes: %{
    "posts" => [
      %{"id" => 10, "title" => "Updated Title"},  # ← ID present = UPDATE
      %{"id" => nil, "title" => "New Post", "body" => "New Content"}  # ← id: nil = CREATE
    ]
  },
  initial_data: %{
    "posts" => [
      %{"id" => 10, "title" => "Original Title"}  # ← Only updated post, not the new one
    ]
  }
}
```

#### Deleting Association Items

```elixir
# Ecto operation
user = Repo.get(User, 1) |> Repo.preload(:posts)
# Assume user has two posts with id: 10 and id: 11

user_changeset = User.changeset(user, %{
  posts: [
    %{id: 10, title: "Updated Title"}  # Keep post 10, delete post 11
  ]
})

Repo.update(user_changeset, success_event: UserUpdated)

# Published event
%UserUpdated{
  changes: %{
    "posts" => [
      %{"id" => 10, "title" => "Updated Title"}
    ]
  },
  initial_data: %{
    "posts" => [
      %{"id" => 10, "title" => "Original Title"}
      # Post 11 was deleted - it's not in changes, indicating deletion
    ]
  }
}
```

### Distinguishing Operations in Event Handlers

Use primary keys to determine the operation type:

```elixir
def handle_event(%UserUpdated{changes: changes}) do
  case changes["posts"] do
    nil ->
      # No post changes
      :ok

    posts when is_list(posts) ->
      Enum.each(posts, fn post ->
        case post["id"] do
          nil ->
            # This is a new post being created
            notify_subscribers_about_new_post(post)

          post_id ->
            # This is an existing post being updated
            notify_subscribers_about_post_update(post_id, post)
        end
      end)
  end
end
```

### Primary Key Handling

**Root aggregates**: Primary keys are NOT included in `changes` or `initial_data` for the root entity. The primary key is used to identify the aggregate but is not tracked as a "change."

**Nested associations**: Primary keys ARE included to distinguish between creates, updates, and deletes within associations.

#### Standard Primary Key (`id`)

Most common case - integer `id` field:

```elixir
schema "users" do
  field(:name, :string)
  field(:email, :string)
  timestamps()
end

# INSERT: PK not included in root changes
%UserCreated{
  changes: %{
    "name" => "John",
    "email" => "john@example.com"
  },
  initial_data: %{
    "name" => nil,
    "email" => nil
  }
}

# UPDATE: PK not included in root changes
%UserUpdated{
  changes: %{
    "email" => "new@example.com"
  },
  initial_data: %{
    "email" => "old@example.com"
  }
}
```

#### Custom Primary Key

Custom field name (e.g., UUID, external ID):

```elixir
schema "api_tokens" do
  field(:token_id, :string, primary_key: true)
  field(:secret, :string)
  field(:expires_at, :naive_datetime)
  timestamps()
end

# INSERT: Custom PK not included in root changes
%TokenCreated{
  changes: %{
    "secret" => "abc123...",
    "expires_at" => ~N[2025-12-31 23:59:59]
  },
  initial_data: %{
    "secret" => nil,
    "expires_at" => nil
  }
}

# UPDATE: Custom PK not included in root changes
%TokenUpdated{
  changes: %{
    "expires_at" => ~N[2026-01-31 23:59:59]
  },
  initial_data: %{
    "expires_at" => ~N[2025-12-31 23:59:59]
  }
}
```

#### Composite Primary Keys

Multiple fields form the primary key:

```elixir
schema "user_permissions" do
  field(:user_id, :integer, primary_key: true)
  field(:resource_id, :integer, primary_key: true)
  field(:permission_level, :string)
  timestamps()
end

# INSERT: Composite PK not included in root changes
%PermissionCreated{
  changes: %{
    "permission_level" => "read"
  },
  initial_data: %{
    "permission_level" => nil
  }
}

# UPDATE: Composite PK not included in root changes
%PermissionUpdated{
  changes: %{
    "permission_level" => "write"
  },
  initial_data: %{
    "permission_level" => "read"
  }
}
```

#### Composite Keys in Associations

When associations have composite keys, all PK fields are included:

```elixir
# Parent with standard PK
schema "projects" do
  field(:name, :string)
  has_many(:tasks, Task)
end

# Child with composite PK
schema "tasks" do
  field(:project_id, :integer, primary_key: true)
  field(:task_number, :integer, primary_key: true)
  field(:title, :string)
  field(:status, :string)
end

# Creating project with tasks
%ProjectCreated{
  changes: %{
    "name" => "New Project",
    "tasks" => [
      %{
        "project_id" => nil,  # ← Composite PK part 1
        "task_number" => nil,  # ← Composite PK part 2
        "title" => "Setup",
        "status" => "pending"
      }
    ]
  },
  initial_data: %{
    "name" => nil,
    "tasks" => []
  }
}

# Updating project with mixed task operations
%ProjectUpdated{
  changes: %{
    "tasks" => [
      %{
        "project_id" => 5,  # ← Existing task (composite PK)
        "task_number" => 1,
        "status" => "completed"
      },
      %{
        "project_id" => nil,  # ← New task (composite PK nil)
        "task_number" => nil,
        "title" => "Review",
        "status" => "pending"
      }
    ]
  },
  initial_data: %{
    "tasks" => [
      %{
        "project_id" => 5,
        "task_number" => 1,
        "status" => "pending"
      }
    ]
  }
}
```

#### No Primary Key

Schemas without primary keys are handled gracefully:

```elixir
schema "audit_logs" do
  field(:action, :string)
  field(:timestamp, :naive_datetime)
end

# No PK fields in changes/initial_data
%AuditLogCreated{
  changes: %{
    "action" => "login",
    "timestamp" => ~N[2025-11-21 12:00:00]
  },
  initial_data: %{
    "action" => nil,
    "timestamp" => nil
  }
}
```

## Usage with Ecto Operations

To publish events from Ecto operations, pass the event module using the `:success_event` option:

```elixir
# Insert
Repo.insert(changeset, success_event: MyApp.Events.UserCreated)

# Update
Repo.update(changeset, success_event: MyApp.Events.UserUpdated)

# Delete
Repo.delete(user, success_event: MyApp.Events.UserDeleted)
```

The event is only published if the operation succeeds.

