# Initial Data Design and Testing Strategy

**Date:** 2025-11-20
**Status:** Approved

## Overview

Design for `initial_data` field in ExEventBus events to enable event handlers to make decisions based on the initial state of data before changes were applied.

## Design Decision: Option A - Changed Fields Only

### Implementation

`initial_data` contains **only the initial values of fields that changed**, not the full record state.

```elixir
# Example: Update user email
changeset.data = %User{name: "John", email: "old@example.com", age: 30}
changeset.changes = %{email: "new@example.com"}

# Result:
initial_data: %{email: "old@example.com"}  # Only changed field
changes: %{email: "new@example.com"}        # Only changed field
aggregate: %User{name: "John", email: "new@example.com", age: 30}  # Full state
```

### Rationale

1. **Symmetry with changes** - Both maps have same keys
2. **Efficient payload** - Only relevant data
3. **Full context available** - `aggregate` provides complete current state
4. **Clear iteration pattern** - Loop through `Map.keys(changes)` and compare `initial_data[key]` vs `changes[key]`

## Operation-Specific Behavior

### Insert (New Record)

```elixir
# New user
changeset.data = %User{name: nil, email: nil, age: nil}
changeset.changes = %{name: "John", email: "john@example.com", age: 30}

# Event:
initial_data: %{name: nil, email: nil, age: nil}
changes: %{name: "John", email: "john@example.com", age: 30}
aggregate: %User{id: 1, name: "John", email: "john@example.com", age: 30}
```

### Update (Existing Record)

```elixir
# Existing user, change email only
changeset.data = %User{id: 1, name: "John", email: "old@example.com", age: 30}
changeset.changes = %{email: "new@example.com"}

# Event:
initial_data: %{email: "old@example.com"}
changes: %{email: "new@example.com"}
aggregate: %User{id: 1, name: "John", email: "new@example.com", age: 30}
```

### Delete (Existing Record)

```elixir
# Delete user - no changeset, no changes
# Event:
initial_data: %{}
changes: %{}
aggregate: %User{id: 1, name: "John", email: "john@example.com", age: 30}
```

## Implementation Changes

### Core Function

```elixir
# lib/ex_event_bus/ecto_repo_wrapper.ex

def get_initial_data(%Ecto.Changeset{data: data, changes: changes}) do
  for {key, _new_value} <- changes, into: %{} do
    {key, Map.get(data, key)}
  end
end
```

## Test Coverage Strategy

### 1. Unit Tests - get_initial_data/1

Location: `test/ex_event_bus/ecto_repo_wrapper_test.exs` (new file)

```elixir
test "extracts only changed fields from changeset data"
test "returns empty map when no changes"
test "handles nested changeset changes"
test "handles nil values in initial data"
test "handles fields not present in initial data"
```

### 2. Unit Tests - build_events/6

Location: `test/ex_event_bus/event_test.exs`

```elixir
test "build_events with initial_data propagates to all events"
test "build_events with single event includes initial_data"
test "build_events with empty list returns empty list"
```

### 3. Unit Tests - create_job_changesets/3

Location: `test/ex_event_bus/publisher_test.exs`

```elixir
test "create_job_changesets includes initial_data in job args"
test "create_job_changesets with nil initial_data"
test "create_job_changesets with multiple subscribers all get initial_data"
```

### 4. Integration Tests - Operation Specific

Location: `test/ex_event_bus/publisher_test.exs` (enhance existing)

```elixir
test "insert operation - initial_data contains nil/default values"
test "update operation - initial_data contains only old values of changed fields"
test "update operation - empty initial_data when no changes"
test "delete operation - initial_data is empty map"
test "Multi transaction with initial_data flows correctly"
```

### 5. Full End-to-End Integration Tests

Location: `test/integration/initial_data_integration_test.exs` (new file)

Complete test module with:
- Real Ecto schema definition
- Changeset functions
- Event definitions using `defevents`
- Full Repo operations (insert, update, delete)
- Verification of Oban job args

```elixir
test "INSERT: real Ecto insert publishes event with nil initial_data"
test "UPDATE: real Ecto update publishes event with old values"
test "DELETE: real Ecto delete publishes event with empty initial_data"
test "UPDATE: multiple fields changed, initial_data has all old values"
test "UPDATE: no changes, no event published"
```

### 6. Edge Cases

Location: Various test files

```elixir
test "empty changeset returns empty initial_data"
test "field changed from nil to value"
test "field changed from value to nil"
test "nested/embedded schema changes"
test "multiple events for same change get same initial_data"
test "struct types preserved in initial_data"
```

## Test Module Structure

### Integration Test Template

```elixir
defmodule ExEventBus.InitialDataIntegrationTest do
  use ExUnit.Case, async: false
  use ExEventBus.Event

  defevents([UserCreated, UserUpdated, UserDeleted])

  defmodule TestUser do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test_users" do
      field :name, :string
      field :email, :string
      field :age, :integer
      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:name, :email, :age])
      |> validate_required([:name, :email])
    end
  end

  # Tests here...
end
```

## Success Criteria

- [ ] All unit tests pass for `get_initial_data/1`
- [ ] All operation-specific tests pass (insert, update, delete)
- [ ] Full integration tests pass with real schemas
- [ ] Edge cases covered and passing
- [ ] No regressions in existing tests
- [ ] Documentation updated in module docs

## Migration Notes

This is a **behavioral change** from capturing full `changeset.data` to capturing only changed fields. Existing event handlers that rely on `initial_data` will need to be reviewed, though most should work since `aggregate` contains full current state.
