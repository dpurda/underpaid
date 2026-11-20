---
name: elixir-expert
description: "Use for any Elixir/Phoenix work: architecture decisions (context vs schema vs GenServer), Ecto query and performance issues (N+1, missing preloads, missing indexes, changeset vs DB constraints), OTP design (supervision trees, GenServer bottlenecks, process state), LiveView correctness, security review, testing strategy, and debugging Elixir-specific errors. Applies across any Elixir project. Defers to a project's own CLAUDE.md for style/convention specifics (formatting, naming, module layout) — this skill is about correctness and design judgment, not house style."
---

# Elixir Expert

Domain judgment for Elixir/Phoenix work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (formatting, naming, module layout) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the exception and stacktrace, the process that crashed (check the supervisor report, not just the last line), and what triggered it (request, LiveView event, job, `iex`). Don't guess-fix. `iex -S mix`, `:observer.start()`, `Process.info/1`, and the logs tell you more than pattern-matching the symptom. A `FunctionClauseError` or `MatchError` usually means unexpected data upstream — find where it came from instead of adding a catch-all clause.

## Ecto

- **N+1 / missing preload**: `Ecto.Association.NotLoaded` or many near-identical queries in the log. Fix with `Repo.preload` or `preload:` in the query at the call site that needs the association — not by loading lazily in a loop.
- **Missing index**: `WHERE`/`JOIN`/`ORDER BY` columns with no index show `Seq Scan` in `EXPLAIN ANALYZE`. Add it in a migration (`create index(...)`, `concurrently: true` on big tables with `@disable_ddl_transaction`).
- **Changesets vs constraints**: `validate_*` is UX; `unique_constraint`/`foreign_key_constraint` only translate DB errors and do nothing without the actual index/constraint in a migration. Back every invariant that matters with the DB.
- **Transactions**: use `Ecto.Multi` (or `Repo.transaction`) for writes that must succeed together. Don't send emails, HTTP calls, or enqueue non-transactional jobs inside — do it after commit (Oban jobs inserted via the Multi are fine, they share the transaction).
- **`{:ok, _}` vs bang**: `Repo.insert!`/`update!` when failure is a bug; the tuple form only when you pattern-match and handle `{:error, changeset}`. Ignoring the return of a non-bang call silently drops failures.

## Where does this logic go?

- **Context module**: the public API for a domain (`Accounts.register_user/1`). Controllers and LiveViews call contexts, never `Repo` directly.
- **Schema module**: fields, associations, changesets. No side effects, no Repo calls.
- **GenServer/process**: only when you need state that lives over time, serialized access to a resource, or concurrency/fault isolation. Don't use a GenServer as a namespace for pure functions — it turns parallel code into a single-process bottleneck.
- Don't invent a behaviour, protocol, or macro for a single implementation. Plain functions and pattern matching first.

## OTP

- Every long-lived process goes under a supervisor with a deliberate restart strategy; no bare `spawn` for anything that matters (use `Task.Supervisor` for fire-and-forget).
- Keep `handle_call` fast — slow work in a call blocks every caller and hits the 5s default timeout. Offload to a `Task` and reply later, or don't funnel the work through one process.
- Let it crash: don't wrap everything in `try/rescue`. Handle expected errors with `{:error, reason}` tuples; let unexpected ones crash and restart to a clean state.
- Watch mailbox growth (`Process.info(pid, :message_queue_len)`) and unbounded state; ETS for read-heavy shared data instead of a single GenServer.

## LiveView

- Load data in `mount` only when `connected?/1` matters; remember `mount` runs twice (static + connected). Use `assign_async`/`start_async` for slow loads.
- Use streams for large or growing collections instead of keeping full lists in assigns.
- Re-authorize in every `handle_event` — the socket can send any event, hiding a button is not a gate.

## Security

- **SQL injection**: never interpolate input into `fragment` or raw SQL; use `^pinned` values and `fragment("... ?", ^x)`.
- **Mass assignment**: `cast/3` only the fields a user may set; never cast `role`, `admin`, owner IDs from params.
- **Atoms**: never `String.to_atom/1` on user input (atoms aren't GC'd — memory DoS); use `String.to_existing_atom/1` or explicit mapping.
- **Authorization**: scope queries by the current user (`where(user_id: ^user.id)`) in the context, not just in templates. Keep CSRF protection on for browser pipelines.
- Don't render `raw/1` on user content; don't leak `inspect(error)` to users.

## Testing (ExUnit)

- Cover happy path, the error tuple / invalid changeset case, and one boundary. Use `async: true` with the Ecto SQL sandbox.
- Mock at the boundary with behaviours + Mox for external services — don't mock your own context under test.
- Test GenServers through their public API, not by poking state; use `start_supervised!` so processes are cleaned up.

## Performance

- Fix the query (preload, index, `select` only needed fields, `Repo.stream` in a transaction for large sets) before adding a cache.
- Background work via Oban (or the project's job library) for slow/unreliable side effects; not for things the response depends on.
- Measure with `:timer.tc`, Benchee, or telemetry before optimizing; process bottlenecks show up as long mailboxes, not CPU.

## When training data is likely stale

Phoenix and LiveView change fast (1.7 verified routes and function components, LiveView 1.0 APIs, `phx.gen.auth` scopes). Check `mix.lock` for actual versions before asserting how something works.
