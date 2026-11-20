---
name: react-expert
description: "Use for any React or Next.js work: hooks rules and stale closures, useEffect misuse and missing cleanup, state design (derived vs stored state, lifting state, keys), rendering performance (unnecessary re-renders, memoization), Server vs Client Components and data fetching in the App Router, hydration errors, accessibility, security review (XSS via dangerouslySetInnerHTML, leaking secrets to the client), testing strategy, and debugging React-specific errors. Applies across any React project. Defers to a project's own CLAUDE.md for style/convention specifics (component layout, naming, styling approach) — this skill is about correctness and design judgment, not house style."
---

# React Expert

Domain judgment for React and Next.js work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (component layout, naming, styling) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the full console error (React links a decoded message for minified errors), the component stack, and whether it happened on the server, during hydration, or on the client. React DevTools (component tree, Profiler "why did this render") and the Next.js dev overlay tell you more than pattern-matching to a known gotcha. Check the React and Next.js versions and whether the project uses the App Router (`app/`) or Pages Router (`pages/`).

## Hooks and effects

- **Rules of hooks**: only call hooks at the top level of a component or custom hook — never in conditions, loops, or after an early return. Keep `eslint-plugin-react-hooks` on and don't disable `exhaustive-deps` to silence it; a missing dependency is a stale-closure bug.
- **You probably don't need an effect**: derive values during render instead of syncing them into state with `useEffect`; handle user actions in event handlers, not effects that watch state. Effects are for syncing with external systems (subscriptions, DOM APIs, timers).
- **Cleanup**: every subscription, listener, interval, or in-flight request started in an effect needs a cleanup (unsubscribe, `clearInterval`, `AbortController.abort()`). Strict Mode's double-invoke in dev surfaces missing cleanups — fix them, don't remove Strict Mode.
- **Data fetching in effects** races (out-of-order responses) and waterfalls. Prefer the framework's data layer (Server Components, route loaders) or the project's existing query library (TanStack Query, SWR) over hand-rolled `useEffect` + `useState`.

## State

- Keep state minimal: don't store what you can compute from props/state. Don't copy props into state unless you mean "initial value".
- Never mutate state (`arr.push`, `obj.x = 1`); return new objects/arrays. Use the functional updater (`setCount(c => c + 1)`) when the next value depends on the previous one.
- **Keys**: use stable IDs from the data, never array index for lists that reorder/insert/delete — index keys mix up component state. Change a `key` to deliberately reset a component's state.
- Lift state to the nearest common parent; reach for Context for genuinely app-wide values (theme, auth), and a store library only once prop drilling and Context actually hurt.

## Server and Client Components (Next.js App Router)

- Components are Server Components by default. Add `"use client"` only at the leaf that needs state, effects, event handlers, or browser APIs — not at the top of the tree.
- Fetch data in Server Components (or route handlers/server actions), not via client effects calling your own API.
- Props crossing to a Client Component must be serializable; never pass secrets. Only `NEXT_PUBLIC_*` env vars reach the browser — use `server-only` for modules that must not be bundled to the client.
- **Hydration errors**: server and client rendered different output — usually `Date.now()`, `Math.random()`, `window`/`localStorage` reads during render, or invalid HTML nesting. Move browser-only values into an effect; don't blanket `suppressHydrationWarning`.
- Server actions are public endpoints: validate input and check authorization inside each one.

## Security

- **XSS**: JSX escapes by default. `dangerouslySetInnerHTML` with any user-controlled content needs sanitization (DOMPurify). Validate `href`/`src` from user data — `javascript:` URLs execute.
- Authorization lives on the server (route handler, server action, API). Hiding a button on the client is not a gate.

## Accessibility

- Use semantic elements: `<button>` for actions, `<a href>` for navigation — not `<div onClick>`. Every input needs a `<label>`; images need meaningful `alt` (or `alt=""` if decorative).
- Manage focus for modals/dialogs (trap and restore), and keep everything keyboard-operable. Run `eslint-plugin-jsx-a11y` if present.

## Testing

- React Testing Library: query by role/label/text the way a user would (`getByRole("button", { name: /save/i })`), not by class names or implementation details. Use `userEvent` over `fireEvent`, and `findBy*`/`waitFor` for async UI.
- Cover the happy path, the empty/loading/error states, and one boundary. Mock the network at the boundary (MSW) rather than mocking hooks or child components.

## Performance

- Measure with the React Profiler before optimizing. Most re-renders are cheap; fix the slow ones.
- First fix state placement (move state down, pass children as props) before reaching for `memo`/`useMemo`/`useCallback` — memoization without stable inputs does nothing. If the React Compiler is enabled, skip manual memoization.
- Virtualize long lists; lazy-load heavy client components (`next/dynamic`, `React.lazy`); use `next/image` for images.

## When training data is likely stale

React 19 (actions, `use`, `useActionState`, ref as a prop, React Compiler) and Next.js caching/fetch defaults changed significantly between major versions. Check `package.json` before asserting how something works — don't assume Pages Router or React 18 semantics on a newer app, or vice versa.
