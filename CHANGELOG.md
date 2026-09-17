# Changelog

## 1.0.0 - 2026-09-17

### Fixed

- Subscriptions no longer vanish when the bus restarts. They used to live in
  an ETS table owned by a `ConCache` process supervised by the bus, while the
  handlers that register them live wherever the application starts them: a
  restart of the bus, of its `State` child or of its Oban instance brought the
  table back empty, no handler re-subscribed, and from then on every
  `Repo.insert/update/delete(..., success_event: ...)` found no subscriber and
  enqueued nothing — silently, since publishing to zero subscribers is a valid
  no-op. Subscriptions are now kept in `:persistent_term`, which no process
  owns, so no restart can drop them and a handler may start before or after
  its bus.

### Changed

- **Breaking:** `ExEventBus.State` is no longer a process. Its `child_spec/1`
  is gone and the bus supervisor now starts only its Oban instance; code that
  started or looked up `MyApp.EventBus.State` must be removed. `add_subscriber/3`
  and `get_subscribers/2` take the bus module (`MyApp.EventBus`) as their first
  argument, and `State.clear/1` erases a bus's subscriptions.
- **Breaking:** subscriptions are global to the node and outlive the bus
  process. A test suite that starts a bus per test must call the new
  `MyApp.EventBus.clear_subscribers/0` before starting it, or subscriptions
  from one test leak into the next. Applications that start the bus once, from
  their supervision tree, are unaffected.
- `con_cache` is no longer a dependency.

## 0.11.0 - 2026-09-09

### Fixed

- `ExEventBus.EctoRepoWrapper` no longer generates a non-changeset fallback
  clause for `update/2`, `update!/2`, `insert_or_update/2` and
  `insert_or_update!/2`. Ecto only accepts a changeset for these functions, so
  the clause was unreachable and Elixir 1.20's type checker reported it as
  `incompatible types given to super/2` in every repo using the wrapper, which
  broke consumers compiling with `--warnings-as-errors`. Calling one of these
  functions with a non-changeset now raises a `FunctionClauseError` from the
  repo's own clause instead of an `ArgumentError` from inside Ecto.
  `insert/2`, `insert!/2`, `delete/2` and `delete!/2` still accept plain
  structs; their fallback clause is now guarded with `is_struct/1`, so a
  non-struct raises a `FunctionClauseError` from the repo instead of from
  `Ecto.Repo.Schema`.

### Changed

- Oban 2.24 or later is now required. Oban 2.24 renamed the internal
  `Oban.Queue.Executor` module that `ExEventBus.ObanDrainer` relies on to
  `Oban.Queues.Executor`. Oban 2.24 also requires its migrations to be at
  version 14, so run `Oban.Migration.up(version: 14)` in your application if
  you have not already.
- All dependencies in `mix.lock` upgraded (ecto 3.14, ecto_sql 3.14,
  postgrex 0.22, db_connection 2.10, decimal 3.1, telemetry 1.4), which clears
  the `mix hex.audit` advisories for decimal and postgrex.
- CI runs on Elixir 1.18.4 / OTP 27 and Elixir 1.20.4 / OTP 29.
- Credo updated to 1.7.19 (dev and test only) for Elixir 1.20 compatibility.
