---
name: typescript-expert
description: "Use for any JavaScript/TypeScript or Node.js work: type design (unions, generics, narrowing, `any`/`unknown`), async/promise bugs (unhandled rejections, missing awaits, races), error handling, npm/pnpm dependency and lockfile issues, ESM vs CommonJS module errors, security review (injection, prototype pollution, XSS), testing strategy, and debugging Node-specific errors. Applies across any JS/TS project. Defers to a project's own CLAUDE.md for style/convention specifics (formatting, naming, file layout) — this skill is about correctness and design judgment, not house style."
---

# TypeScript Expert

Domain judgment for JS/TS and Node work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (formatting, naming, file layout) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the full error and stack trace, the `tsc` diagnostic code (`TS2345` etc.), and where it ran (Node version, browser, bundler, test runner). Run `tsc --noEmit` and the failing test directly rather than guessing. Check `package.json` (`"type"`, `engines`, scripts) and `tsconfig.json` (`strict`, `module`, `moduleResolution`) before asserting how anything resolves.

## Types

- **`any` is an off switch**: it silently spreads. Use `unknown` for untrusted input and narrow it (type guards, `in`, `instanceof`, or a schema validator like zod if the project already has one). Don't silence an error with `as` or `// @ts-ignore` — a cast is a claim the compiler can't check; fix the type or narrow.
- **Validate at the boundary**: `JSON.parse`, `fetch().json()`, env vars, and request bodies are `unknown` at runtime no matter what the type annotation says. Parse once at the edge, trust types inside.
- **Discriminated unions** over optional-field bags for state (`{ status: "ok"; data } | { status: "error"; error }`), with an exhaustive `switch` ending in a `never` check.
- Don't build a generic for one caller. A generic with one instantiation is premature abstraction.
- Keep `strict: true` on; don't loosen `tsconfig` to make an error go away.

## Async and promises

- **Missing `await`**: the #1 async bug — a returned promise nobody awaits means errors vanish and ordering breaks. Enable `@typescript-eslint/no-floating-promises` if lint exists.
- **`forEach` with async callbacks** doesn't wait. Use `for...of` with `await` for sequential, `Promise.all(items.map(...))` for parallel; `Promise.allSettled` when one failure shouldn't drop the rest.
- Unbounded `Promise.all` over thousands of items will exhaust sockets/rate limits — batch or use a small concurrency limiter.
- Don't wrap an existing promise in `new Promise(...)` (the explicit-construction anti-pattern); use `util.promisify` for callback APIs.
- Use `AbortController` for timeouts/cancellation on `fetch` and long operations rather than racing a `setTimeout`.

## Error handling

- Throw `Error` instances (or subclasses), never strings/objects — you lose the stack. Use `new Error(msg, { cause })` when rewrapping.
- In `catch (e)`, `e` is `unknown`: narrow before reading `.message`.
- Don't swallow errors with an empty `catch` or `.catch(() => {})`. Handle it, or let it propagate to one top-level handler.
- In Node, an unhandled rejection crashes the process — that's correct; fix the source, don't add a global handler that ignores it.

## Modules and packages

- **ESM vs CJS**: `ERR_REQUIRE_ESM`, `Cannot use import statement outside a module`, and `__dirname is not defined` are module-format mismatches. Check `"type"` in `package.json`, file extensions (`.mjs`/`.cjs`/`.mts`), and `tsconfig` `module`/`moduleResolution` (`NodeNext` for Node). In ESM, relative imports need the file extension.
- Use the project's existing package manager (lockfile tells you: `pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`); never mix them or delete the lockfile to "fix" an install. Use `npm ci`/`pnpm install --frozen-lockfile` in CI.
- Before adding a dependency, check whether the stdlib or an installed package already does it (`fetch`, `structuredClone`, `node:crypto`, `node:test`).

## Security

- **Injection**: never build SQL, shell commands, or HTML with string interpolation of user input. Parameterized queries; `execFile`/`spawn` with an args array, not `exec` with a string.
- **XSS**: avoid `innerHTML`/`document.write` with untrusted data; use `textContent` or a framework's escaped rendering. Sanitize (DOMPurify) if raw HTML is genuinely required.
- **Prototype pollution**: don't deep-merge or assign user-controlled keys into plain objects (`__proto__`, `constructor`); use `Map` or validate keys.
- No `eval`/`new Function` on input. Keep secrets in env vars, never in client bundles or logs. Run `npm audit`/`pnpm audit` before reaching for a fix.

## Testing

- Use the runner the project already has (Vitest, Jest, `node:test`). Cover the happy path, the empty/null/undefined case, and one boundary.
- Always `await` (or return) async assertions, and use `expect(...).rejects` for failures — otherwise the test passes before the promise settles.
- Mock at the boundary (HTTP, filesystem, clock via fake timers) — not the function under test. Restore mocks between tests.

## Performance

- Measure first (`--cpu-prof`, `console.time`, Chrome DevTools) before optimizing.
- Never block the event loop with sync I/O (`readFileSync`, heavy CPU) in a request path; use async APIs or a worker thread.
- Stream large files/responses instead of buffering them into memory.

## When training data is likely stale

Node, TypeScript, and bundlers move fast (native `fetch`, `--experimental-strip-types`, `satisfies`, `using`, new `moduleResolution` modes). Check the actual versions in `package.json`/lockfile and `node --version` before asserting what's supported.
