# ExEventBus

ExEventBus provides an event bus that uses the outbox pattern.  Behind the scenes, 
it relies on Oban and ConCache.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_event_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_event_bus, "~> 0.10.0"}
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

Events published by ExEventBus contain:

- **`aggregate`**: The complete struct of the affected entity
- **`changes`**: Map of fields that changed (from `changeset.changes`)
- **`initial_data`**: Map of previous values (mirrors `changes` structure)
- **`metadata`**: Optional metadata passed to the operation

### How It Works

`changes` and `initial_data` directly mirror your Ecto changeset - only fields that actually changed are included:

```elixir
# Simple update
%MyEvent{
  aggregate: %User{id: 1, name: "Jane Doe", email: "jane.doe@example.com"},
  changes: %{"email" => "jane.doe@example.com"},
  initial_data: %{"email" => "jane@example.com"},
  metadata: nil
}
```

### INSERT Operations

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

### UPDATE Operations

```elixir
%UserUpdated{
  aggregate: %User{id: 1, email: "new@example.com", age: 30},
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

### DELETE Operations

```elixir
%UserDeleted{
  aggregate: %User{id: 1, name: "John"},
  changes: %{},
  initial_data: %{}
}
```

## Association Changes

Associations in `changes` and `initial_data` work the same way - they mirror what's in the changeset:

### Creating with Associations

```elixir
# Ecto operation
user_changeset = User.changeset(%User{}, %{
  name: "Alice",
  email: "alice@example.com",
  profile: %{bio: "Software Engineer"},
  posts: [
    %{title: "First Post", body: "Hello World"}
  ]
})

Repo.insert(user_changeset, success_event: UserCreated)

# Published event
%UserCreated{
  changes: %{
    "name" => "Alice",
    "email" => "alice@example.com",
    "profile" => %{"bio" => "Software Engineer"},
    "posts" => [
      %{"title" => "First Post", "body" => "Hello World"}
    ]
  },
  initial_data: %{
    "name" => nil,
    "email" => nil,
    "profile" => nil,
    "posts" => []
  }
}
```

### Updating Associations

```elixir
# Ecto operation
user = Repo.get(User, 1) |> Repo.preload([:profile, :posts])

user_changeset = User.changeset(user, %{
  profile: %{id: user.profile.id, bio: "Senior Engineer"},
  posts: [
    %{id: 10, title: "Updated Title"},
    %{title: "New Post", body: "New Content"}
  ]
})

Repo.update(user_changeset, success_event: UserUpdated)

# Published event
%UserUpdated{
  changes: %{
    "profile" => %{"bio" => "Senior Engineer"},
    "posts" => [
      %{"title" => "Updated Title"},
      %{"title" => "New Post", "body" => "New Content"}
    ]
  },
  initial_data: %{
    "profile" => %{"bio" => "Engineer"},
    "posts" => [
      %{"title" => "Original Title"},
      %{}  # New item - no previous value
    ]
  }
}
```

### Using in Event Handlers

Simply check if fields exist in `changes`:

```elixir
def handle_event(%UserUpdated{changes: changes, initial_data: initial_data}) do
  # React to email changes
  if Map.has_key?(changes, "email") do
    send_email_change_notification(
      old_email: initial_data["email"],
      new_email: changes["email"]
    )
  end

  # React to association changes
  if Map.has_key?(changes, "posts") do
    notify_posts_changed()
  end
end
```

## Supported Field Types

ExEventBus fully supports all Ecto field types, including:

- **Primitive types**: `:string`, `:integer`, `:float`, `:boolean`, `:date`, `:time`, `:naive_datetime`, `:utc_datetime`, etc.
- **Primitive arrays**: `{:array, :string}`, `{:array, :integer}`, `{:array, Ecto.UUID}`, etc. with `default: []`
- **Custom types**: Any Ecto type including `Ecto.Enum`, embedded schemas, etc.
- **Associations**: `has_one`, `has_many`, `belongs_to` with full change tracking

Primitive array fields (like `field(:tags, {:array, :string}, default: [])`) are properly tracked as field changes, while association arrays are tracked with individual item primary keys.

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

