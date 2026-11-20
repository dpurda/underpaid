---
name: rust-expert
description: "Use for any Rust work: ownership and borrow-checker errors, lifetime issues, error handling design (Result, ?, thiserror vs anyhow), async/tokio correctness (blocking in async, Send bounds, cancellation), cargo/workspace and feature issues, unsafe review, testing strategy, and performance. Applies across any Rust project. Defers to a project's own CLAUDE.md for style/convention specifics (formatting, naming, module layout) — this skill is about correctness and design judgment, not house style."
---

# Rust Expert

Domain judgment for Rust work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (formatting, naming, module layout) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the full compiler error, including the notes and `help:` lines and the error code (`rustc --explain E0502`). The compiler usually tells you exactly which borrow conflicts and where. Don't guess-fix by sprinkling `.clone()`, `Rc<RefCell<>>`, or `'static` until it compiles — understand who should own the data first. For runtime issues: `RUST_BACKTRACE=1`, `cargo test -- --nocapture`, `tracing` logs, and `tokio-console` for async stalls.

## Ownership and borrowing

- **Borrow conflicts**: usually fixed by restructuring — shorten the borrow's scope, split the struct borrow into fields, or compute a value before taking `&mut`. Clone only when shared ownership is genuinely what you want, and say so.
- **Lifetimes**: if a struct needs many lifetime parameters, it probably should own its data (`String` over `&str`). Return owned values from functions unless the borrow clearly ties to an input.
- **Shared mutable state**: `Arc<Mutex<T>>` across threads, `Rc<RefCell<T>>` single-threaded — but reach for message passing or a clear single owner first. `RefCell` borrow panics are runtime bugs the compiler can't catch.
- Accept `&str`/`&[T]`/`impl AsRef` in parameters, return owned types. Don't take `&String` or `&Vec<T>`.

## Error handling

- Libraries: typed errors (`thiserror` enum) so callers can match. Applications: `anyhow` with `.context("what was being done")` at each layer.
- `unwrap()`/`expect()` only for true invariants (with an `expect` message explaining why it can't fail) and in tests. Everywhere else, propagate with `?`.
- Don't swallow errors with `let _ =` or `.ok()` on anything that writes, sends, or commits — a dropped `Result` is a silent data-loss bug.
- Panics are for bugs, not for expected failures like bad input or network errors.

## Async / tokio

- **Never block the runtime**: no `std::thread::sleep`, sync file/network I/O, or heavy CPU work in an async fn — use `tokio::time::sleep`, tokio I/O, or `spawn_blocking`.
- **Locks across `.await`**: holding a `std::sync::Mutex` guard across `.await` makes the future `!Send` or deadlocks. Drop the guard before awaiting, or use `tokio::sync::Mutex` only when you truly must hold it across awaits.
- **Cancellation**: any future can be dropped at an `.await` (e.g. in `select!` or on timeout). Make sure partial work leaves state consistent; check `select!` branches for cancellation safety.
- Spawned tasks: keep the `JoinHandle` (or a `JoinSet`) and handle its result — a panicking detached task fails silently.
- Bound concurrency (`Semaphore`, `buffer_unordered(n)`) and channels; unbounded ones turn load spikes into OOMs.

## Cargo

- Check `Cargo.lock` and `cargo tree -d` for duplicate/conflicting versions before blaming code. Features are additive and unified across the workspace — a feature enabled anywhere is enabled everywhere.
- Don't add a crate for what std or an existing dependency already does. `cargo clippy` and `cargo fmt` before declaring done.

## Unsafe

- Avoid unless there's a measured need or FFI. Every `unsafe` block gets a `// SAFETY:` comment stating the invariant that makes it sound.
- Keep unsafe minimal and wrapped in a safe API that enforces the invariant. Run `cargo miri test` on code that touches raw pointers or `transmute`.
- No `transmute` where `from_ne_bytes`, `as`, or a safe cast works; no `get_unchecked` without a benchmark proving bounds checks matter.

## Security

- Validate and bound all untrusted input (lengths, sizes before allocating, recursion depth when parsing).
- SQL: use parameterized queries (`sqlx` binds / query macros), never `format!` into SQL. Shell: `Command::new(prog).arg(x)`, never pass user input through `sh -c`.
- Run `cargo audit`/`cargo deny` for vulnerable dependencies. Don't log secrets; don't derive `Debug` on types holding them without redaction.

## Testing

- Unit tests in `#[cfg(test)] mod tests` next to the code; integration tests in `tests/` against the public API. `#[tokio::test]` for async.
- Cover happy path, the `Err` case, and one boundary (empty, zero, max). Property tests (`proptest`) for parsers and invariants.
- Abstract external services behind a trait only at the boundary for testing; don't trait-ify every struct.

## Performance

- Measure first (`cargo bench`/criterion, `perf`/flamegraph), and always in `--release`.
- Common wins: avoid needless `clone`/`collect`, preallocate with `with_capacity`, iterate instead of indexing, `&str` over `String` in hot paths.
- Algorithmic and I/O fixes (batching, buffering with `BufReader`/`BufWriter`) beat micro-optimizing or reaching for unsafe.

## When training data is likely stale

Rust editions and async ecosystems move (edition 2024, async fn in traits, tokio/axum major versions). Check `Cargo.toml` edition and `Cargo.lock` versions before asserting an API or limitation.
