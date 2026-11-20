---
name: vue-expert
description: "Use for any Vue 3 or Nuxt work: Composition API design (composables, script setup), reactivity pitfalls (lost reactivity from destructuring, ref vs reactive, watchers), Pinia store design, component communication (props, emits, v-model, provide/inject), SSR and hydration issues in Nuxt (useFetch/useAsyncData, state leaking between requests), security review (v-html XSS, leaking runtime config), testing strategy, and rendering performance. Applies across any Vue project. Defers to a project's own CLAUDE.md for style/convention specifics (component layout, naming, Options vs Composition API preference) — this skill is about correctness and design judgment, not house style."
---

# Vue Expert

Domain judgment for Vue 3 and Nuxt work: what's actually wrong, and the boring, idiomatic way to fix it. A project's own CLAUDE.md always wins on style (component layout, naming, API style) — this skill fills the gaps it doesn't cover.

## Diagnose before reaching for a pattern

Read the actual failure first: the full console warning (Vue's dev warnings name the component and prop), whether it happened on the server, during hydration, or on the client, and the Vue/Nuxt versions. Vue DevTools (component state, Pinia timeline) and `vue-tsc --noEmit` tell you more than pattern-matching to a known gotcha.

## Reactivity pitfalls

- **Destructuring loses reactivity**: `const { x } = reactive(obj)` or destructuring props gives a plain snapshot. Use `toRefs`/`storeToRefs`, access `props.x` directly, or rely on reactive props destructure only if the project's Vue version (3.5+) supports it.
- **`ref` vs `reactive`**: default to `ref` — it works for any value and survives reassignment. Reassigning a `reactive` variable (`state = {...}`) breaks every reference to it. Remember `.value` in script (auto-unwrapped only in templates).
- **Derive, don't sync**: use `computed` for values derived from state instead of a `watch` that writes into another ref. Computeds must be side-effect free.
- **Watchers**: `watch` needs a getter for a reactive property (`watch(() => props.id, ...)`), not the raw value. Use `deep` only when needed; use `onWatcherCleanup`/the `onCleanup` arg to cancel stale async work.
- Don't mutate props. Emit an event or use `defineModel` for two-way binding.
- **Keys**: `v-for` needs a stable `:key` from the data, never the index for lists that reorder. Never put `v-if` and `v-for` on the same element.

## Composables and state

- Extract a composable when logic is reused by 2+ components, not for one caller. Composables must be called synchronously in `setup` (not after an `await` or in a callback) so lifecycle hooks and injection bind correctly.
- Clean up what you start: listeners, intervals, and subscriptions get removed in `onUnmounted` (or use the project's VueUse helpers that auto-clean).
- **Pinia**: use it for genuinely shared state, not every component's local state. Use `storeToRefs` when destructuring state/getters; actions can be destructured directly. Keep async logic in actions, not components poking at store state.
- provide/inject for subtree-scoped dependencies; type the key with `InjectionKey`.

## Nuxt and SSR

- **Cross-request state leaks**: module-level `ref`/`reactive` on the server is shared by every user. Use `useState`, Pinia (per-request in Nuxt), or composable-local state instead.
- Fetch with `useFetch`/`useAsyncData` in setup so data is serialized to the client — a raw `$fetch` in setup runs twice (server and client). Use `$fetch` in event handlers. Give `useAsyncData` a unique key.
- **Hydration mismatches**: caused by `Date.now()`, random values, or `window`/`localStorage` access during render. Move browser-only code into `onMounted` or `<ClientOnly>`.
- Only `runtimeConfig.public` reaches the browser; secrets stay in private runtime config and server routes (`server/api`).

## Security

- **XSS**: template interpolation escapes by default. `v-html` with any user-controlled content needs sanitization (DOMPurify). Validate user-supplied `:href`/`:src` (`javascript:` URLs execute). Never compile user input as a template.
- Authorization belongs in server routes/the API; `v-if` hiding a button is not a gate. Validate input in every Nuxt server route.

## Testing

- Vitest + Vue Test Utils (or Testing Library) — test through rendered output and emitted events, not internal component state. `await` `nextTick`/`flushPromises` after state changes.
- Use `@pinia/testing`'s `createTestingPinia` for store-dependent components. Mock the network at the boundary, not composables under test.
- Cover the happy path, empty/loading/error states, and one boundary.

## Performance

- Measure with Vue DevTools' performance tab before optimizing.
- Use `computed` (cached) over methods called in templates; `shallowRef`/`markRaw` for large non-reactive data (big arrays, third-party class instances) instead of deep reactivity.
- `v-show` for frequently toggled elements, `v-if` for rarely shown ones; lazy-load routes and heavy components (`defineAsyncComponent`, Nuxt `Lazy` prefix); virtualize long lists.

## When training data is likely stale

Vue 3.4/3.5 added `defineModel`, reactive props destructure, and `useTemplateRef`; Nuxt 3 vs 4 changed directory layout and data-fetching defaults. Check `package.json` before asserting how something works — and never assume Vue 2/Options-only semantics on a Vue 3 app.
