# Changelog

## 0.10.1 - 2026-09-09

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

- CI runs on Elixir 1.18.4 / OTP 27 and Elixir 1.20.4 / OTP 29.
- Credo updated to 1.7.19 (dev and test only) for Elixir 1.20 compatibility.
