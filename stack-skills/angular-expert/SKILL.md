---
name: angular-expert
description: "Use for any Angular work: component design (standalone components, inputs/outputs, smart vs presentational), signals vs RxJS and subscription leaks, change detection (OnPush, zoneless, ExpressionChangedAfterItHasBeenChecked), dependency injection scope, reactive forms and validation, security review (XSS and bypassSecurityTrust*), testing strategy, rendering performance, and debugging Angular-specific errors. Applies across any Angular project. Defers to a project's own CLAUDE.md for style/convention specifics (file layout, naming, module vs standalone preference) — this skill is about correctness and design judgment, not house style."
---

# Angular Expert

Domain judgment for Angular work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (file layout, naming, module structure) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the full error with its `NG0xxx` code (the linked angular.dev page explains it), the component involved, and whether it occurs in the browser, SSR, or tests. Angular DevTools (component tree, change-detection profiler) and `ng build` type errors tell you more than pattern-matching to a known gotcha. Check the Angular version in `package.json` — signals, control flow, and zoneless changed a lot.

## Signals and RxJS

- **Subscription leaks**: every manual `.subscribe()` in a component needs teardown. Prefer the `async` pipe or `toSignal()` (auto-unsubscribe), else `takeUntilDestroyed()`. HTTP observables complete on their own; `valueChanges`, router events, intervals, and store selects do not.
- **Signals for state, RxJS for events over time**: use `signal`/`computed` for component state and derived values; keep RxJS for streams (debounced search, websockets, cancellation). Bridge with `toSignal`/`toObservable` rather than mixing both for the same state.
- Use `computed` for derived values, not an `effect` that writes to another signal. Effects are for syncing with the outside world (DOM, localStorage, logging).
- **Nested subscribes** are a smell — use `switchMap` (cancel previous, e.g. search), `concatMap` (ordered writes), `mergeMap` (parallel), or `exhaustMap` (ignore while busy, e.g. submit). Picking the wrong one causes races or duplicate writes.
- Handle errors inside the inner observable (`catchError` in the `switchMap`) — an error reaching the outer stream kills it permanently.

## Change detection

- Use `ChangeDetectionStrategy.OnPush` for new components, and feed them immutable inputs or signals. Mutating an input object in place won't re-render an OnPush child — replace it.
- `ExpressionChangedAfterItHasBeenCheckedError` means a value changed during the check (often a parent updated from a child's lifecycle hook). Fix the data flow; don't wrap it in `setTimeout` or call `detectChanges()` to hide it.
- Don't call methods or build new objects/arrays in template bindings — they run every check. Use `computed` signals or pure pipes.

## Components, DI, and forms

- Smart containers fetch data and hold state; presentational components take `input()`s and emit `output()`s. Don't put HTTP calls in presentational components.
- `providedIn: 'root'` for app-wide singletons; component-level `providers` give each instance its own copy — know which you want, since the wrong scope causes "state isn't shared" or "state leaks between instances" bugs.
- Use `inject()` or constructor injection consistently with the project; don't new up services manually.
- **Reactive forms** over template-driven for anything non-trivial; use typed forms (`FormGroup<{...}>`/`NonNullableFormBuilder`). Validation in forms is UX — the server must validate again.

## Security

- **XSS**: Angular sanitizes interpolation and `[innerHTML]` by default. `bypassSecurityTrustHtml`/`Url`/`ResourceUrl` turn that off — only use with content you fully control, never user input. Avoid direct DOM writes via `ElementRef.nativeElement.innerHTML`.
- Route guards are UX, not security — every API call must be authorized on the server. Keep secrets out of `environment.ts`; it ships to the browser.
- Use `HttpClient` interceptors for auth headers and rely on its XSRF support for cookie-based sessions.

## Testing

- Prefer Angular Testing Library or `TestBed` with real child components where cheap; query by role/text, not CSS classes. Use `HttpTestingController` to mock HTTP at the boundary and `verify()` no outstanding requests.
- Use `fakeAsync`/`tick` or `await fixture.whenStable()` for async; call `fixture.detectChanges()` after state changes (or test via signals/zoneless setup).
- Cover the happy path, empty/loading/error states, and one boundary. Don't mock the service under test.

## Performance

- Profile with Angular DevTools before optimizing.
- `@for` requires `track` — track by a stable id, not the object identity or `$index` for lists that change. Virtualize long lists (CDK `cdk-virtual-scroll-viewport`).
- Lazy-load routes (`loadComponent`/`loadChildren`) and use `@defer` for heavy below-the-fold blocks. Use `NgOptimizedImage` for images.

## When training data is likely stale

Angular moves fast: standalone by default (v17+), built-in control flow (`@if`/`@for`), signal inputs/outputs/queries, `linkedSignal`/`resource`, and zoneless change detection. Check the version in `package.json` before asserting how something works — don't assume NgModule/zone.js semantics on a newer app, or vice versa.
