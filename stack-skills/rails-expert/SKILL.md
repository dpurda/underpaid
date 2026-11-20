---
name: rails-expert
description: "Use for any Ruby on Rails work: architecture decisions (model vs service vs concern), ActiveRecord query and performance issues (N+1, missing indexes, callback ordering), security review (mass assignment, SQL injection, CSRF), testing strategy, and debugging Rails-specific errors. Applies across any Rails project. Defers to a project's own CLAUDE.md for style/convention specifics (block syntax, file layout, naming) — this skill is about correctness and design judgment, not house style."
---

# Rails Expert

Domain judgment for Rails work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (syntax, naming, file layout) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the error class + message, the model/controller/job involved, and what triggered it (request, background job, console, migration). Don't guess-fix. `bin/rails runner`, `rails console`, and the log (`log/development.log` or the test failure output) tell you more than pattern-matching the symptom to a known Rails gotcha.

## ActiveRecord

- **N+1**: symptom is many near-identical SELECTs in the log for one request. Fix with `includes`/`preload`/`eager_load` at the query site that renders the association, not by caching. Use `bullet` gem output if present instead of eyeballing logs.
- **Missing index**: a `WHERE`, `JOIN`, or `ORDER BY` column with no index shows up as `Seq Scan` in `EXPLAIN ANALYZE`. Add the index in a migration; don't work around it in Ruby.
- **Callbacks**: prefer explicit service/method calls over `before_save`/`after_commit` chains for anything with side effects (emails, external API calls, jobs) — callbacks that aren't pure data validation are the #1 source of "why did this fire twice" bugs. If a callback already exists and works, don't rip it out mid-task; note the smell and move on unless asked to fix it.
- **Transactions**: wrap multi-model writes that must succeed or fail together in `ActiveRecord::Base.transaction { }`. Don't send external side effects (emails, HTTP calls, background jobs) inside the transaction block — use `after_commit` or enqueue after the transaction closes, since a rollback can't undo them.
- **Validations vs DB constraints**: validations are UX, not a safety net — always back a uniqueness/not-null validation with a DB-level constraint/index if the invariant actually matters, since race conditions bypass validations.
- **`update` vs `update!` / `save` vs `save!`**: use the bang form when a failure should raise (data corruption risk), the non-bang form only when you're checking the boolean and handling the failure explicitly. Silently swallowed `false` returns are a classic Rails bug.

## Where does this logic go?

- **Model method**: logic that's purely about one record's own data (a computed attribute, a simple predicate).
- **Concern**: behavior shared by 2+ models — but only extract once there are actually 2+ users; a concern with one includer is premature abstraction.
- **Service object**: anything that touches multiple models, calls an external system, or has a "workflow" (steps that can each fail). This is where most non-trivial logic should live.
- **Controller**: HTTP concerns only — params, authorization, response shape. If a controller action has branching business logic, that's a sign it belongs in a service.
- Don't invent a form object, query object, or presenter for a one-off — that's for genuinely recurring shapes (a form backing 3+ fields across models, a query reused in 3+ places).

## Security

- **Mass assignment**: every create/update path must go through `params.require(...).permit(...)` (strong params) — never `params[:model]` directly into `.new`/`.update`.
- **SQL injection**: never interpolate user input into `where("... #{x}")`, `order`, or raw SQL. Use `where(column: value)` or `?`/named placeholders (`where("x = ?", value)`).
- **CSRF**: `protect_from_forgery` should be on for any session-based controller; don't disable it to make a request "just work" without understanding why it was failing.
- **Authorization**: every controller action needs an explicit authorization check (Pundit `authorize`/`policy_scope`, CanCanCan, or equivalent) — don't rely on views hiding a link as the only gate.
- Never log or flash raw exception messages (`e.message`) to end users — they can leak internals (queries, file paths, secrets). Log to an error tracker (Honeybadger, Sentry) instead, show a generic user-facing message.

## Testing (RSpec, general)

- Cover: happy path, the nil/empty/missing case, and one boundary condition. Don't write a spec for every permutation of a simple guard clause.
- Prefer `let`/`subject` over instance variables in specs for laziness and isolation; but don't over-abstract shared setup into deeply nested `shared_examples` for a one-off test.
- Stub at the boundary (HTTP client, external gem call) — not the method under test. A test that stubs the thing it's testing proves nothing.
- Use factories (FactoryBot) over fixtures for anything with associations; keep factory definitions minimal (only required attributes), add traits for variations instead of duplicate factories.

## Performance

- Reach for `counter_cache`, `includes`, and DB indexes before reaching for a caching layer (Rails.cache/Redis) — caching adds invalidation complexity that a correct query often avoids.
- Background jobs (Sidekiq/ActiveJob) for anything slow or unreliable in the request cycle (email, external API, report generation) — not for things that must be consistent before the response returns.
- `pluck`/`select` over loading full records when you only need a few columns; `find_each`/`in_batches` over `.all.each` for anything that could be large, to avoid loading the whole table into memory.

## When training data is likely stale

Rails release cadence moves fast (new Zeitwerk behavior, Hotwire/Turbo defaults, `Rails.application.config.load_defaults`). If behavior seems off from what you'd expect, check the project's actual Rails version (`Gemfile.lock`) before asserting how something works — don't assume Rails 6 semantics on a Rails 7+ app or vice versa.
