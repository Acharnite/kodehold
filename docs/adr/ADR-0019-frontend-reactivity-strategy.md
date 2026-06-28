# ADR-0019: Frontend Reactivity Strategy for DeepResearch

## Status

Proposed

## Context

### Current State

The DeepResearch frontend is a vanilla JavaScript SPA served directly by FastAPI static files — no build step, no Node.js pipeline. The codebase consists of:

| Metric | Value |
|--------|-------|
| JavaScript files | 16 (in `static/js/` and `static/js/views/`) |
| JavaScript LOC | 4,177 |
| HTML (demo.html) | 750 lines |
| CSS (dashboard.css) | 692 lines |
| Total frontend LOC | ~5,619 |

### Architecture Patterns in Use

The current code uses several patterns that create friction:

1. **Plain state object** (`state.js`, 32 lines) — a mutable JS object with getter functions (`getState()`). No reactivity: when `state.agents` changes, no DOM updates happen automatically. Every consumer must manually call render functions.

2. **Window globals for cross-module communication** — views register functions on `window` (e.g., `window.showSessions`, `window.showDetail`, `window.deleteSession`, `window.saveApiKey`). HTML uses `onclick="window.someFunction()"` inline handlers. This creates implicit coupling and makes the dependency graph invisible.

3. **String-concatenation HTML generation** — views build HTML via `+=` string concatenation (see `session-list.js` lines 84-108, `settings.js` lines 28-51). This is error-prone (XSS risk if `esc()` is forgotten), hard to read, and makes partial DOM updates impossible.

4. **Full re-render on every change** — `refreshSessionList()` rebuilds the entire session list HTML every 3 seconds via polling. `innerHTML` assignment destroys and recreates all DOM nodes, losing scroll position, focus, and input state. This is a primary source of the reported "jank."

5. **Manual event rebinding** — after every `innerHTML` assignment, event listeners must be re-attached (`bindToolbarEvents()`, `bindBulkEvents()`). Forgetting a bind path creates silent bugs.

6. **Circular dependency workarounds** — `sse.js` uses `import('./views/session-detail.js')` dynamic import to break a circular dependency between SSE handling and the detail view.

### Pain Points

- **Jank**: Full DOM rebuilds every 3 seconds cause visible flicker, scroll jumps, and input focus loss.
- **Fragile state**: Manual synchronization between JS state and DOM means bugs where state is updated but DOM isn't, or vice versa.
- **Invisible coupling**: Window globals make it impossible to trace which module depends on which without reading all files.
- **Large view files**: `settings.js` is 1,649 lines, `session-detail.js` is 708 lines — both are monolithic because there's no component abstraction to break them apart.

### Constraints

- **Python team**: The maintainers are Python/FastAPI developers, not frontend specialists. Any solution must have a low learning curve.
- **No build step**: The project serves static files directly via FastAPI. Adding Node.js/npm as a build dependency is strongly preferred against.
- **Incremental migration**: A full rewrite is not feasible. Changes must be adoptable one view at a time.
- **Bundle size**: The frontend should remain lightweight. The current JS is ~4,200 lines (~120KB uncompressed). Adding tens of KB is acceptable; adding hundreds is not.

## Decision Drivers

| Driver | Weight | Notes |
|--------|--------|-------|
| Reactivity | High | Eliminating manual DOM updates is the primary goal |
| Build complexity | High | No build step is a hard constraint |
| Migration effort | High | Must be incremental, not a rewrite |
| Learning curve | High | Python team, not frontend specialists |
| Long-term maintainability | Medium | Should reduce code, not add to it |
| Bundle size / performance | Medium | Must not regress current performance |
| Community / ecosystem | Medium | Framework should be well-documented and stable |

## Considered Options

### Option A: Alpine.js Adoption

**What it is**: Alpine.js is a 15KB (gzipped) declarative framework that adds reactivity via HTML attributes (`x-data`, `x-show`, `x-on`, `x-for`, `x-model`). It runs in the browser with no build step — include via `<script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>`.

**Pros**:
- Directly solves the reactivity problem: `x-data` creates reactive state, `x-show`/`x-for` auto-update DOM when state changes.
- No build step — CDN include, works with existing FastAPI static serving.
- Incremental adoption — add `x-data` to one `<div>` at a time, leave the rest vanilla.
- Declarative HTML attributes are easy to read: `<div x-data="{ open: false }">` is self-documenting.
- `Alpine.store()` provides shared state that replaces window globals cleanly.
- Active community (28K+ GitHub stars), excellent documentation, Alpine devtools for debugging.
- Template syntax (`x-for`, `x-if`) eliminates string concatenation HTML generation.
- `x-transition` provides built-in animations that can smooth out the jank during view switches.

**Cons**:
- Adds a dependency (15KB gzipped). Per ADR-0049 (The Ladder), this needs justification.
- Different paradigm from current code (declarative vs imperative). Learning curve for the team.
- During migration, two systems coexist: Alpine-managed views and vanilla views.
- Less control over the reactivity model — if Alpine's proxy-based reactivity has edge cases, debugging requires understanding the framework internals.
- Alpine's `x-html` (innerHTML equivalent) has XSS implications if used carelessly with user content.

### Option B: Vanilla Cleanup (Custom Mini-Reactive Layer)

**What it is**: Extract a ~100-200 line reactive state manager from scratch. Replace window globals with an event bus. Standardize on template literal HTML. Add a simple component pattern (factory functions returning DOM elements).

**Pros**:
- Zero dependencies — maintains the current zero-dependency approach.
- Full control over the reactivity model.
- No new paradigm — the team stays in vanilla JS.
- No migration period with mixed paradigms.
- Satisfies The Ladder (ADR-0049) — stdlib-only, no new deps.

**Cons**:
- Must build reactivity from scratch. A minimal reactive system (Proxy-based state, dependency tracking, dirty checking, DOM patching) is 150-300 lines for a basic version, and still won't match Alpine's polish.
- Still requires manual DOM updates for complex views — the custom layer handles simple cases but breaks down for nested lists, conditional rendering, and transitions.
- More code to maintain long-term — the custom reactive layer becomes a framework the team must maintain.
- No community support — if the custom layer has bugs, there's no Stack Overflow, no devtools, no documentation.
- Harder for new contributors — they must learn a custom pattern instead of a well-known framework.
- Template literal HTML is better than string concatenation but still doesn't solve the fundamental problem: JS must manually call render functions when state changes.

### Option C: Stay Vanilla, Minimal Cleanup (Not Fully Explored)

A lighter version of Option B: just replace window globals with an event bus, standardize on template literals, and accept that manual DOM updates remain. This is the "do nothing about reactivity" path. Rejected because it doesn't address the primary pain point (jank from manual DOM management).

## Comparison Matrix

| Dimension | Alpine.js | Vanilla Cleanup |
|-----------|-----------|----------------|
| Bundle size | 15KB gzipped | 0KB |
| Reactivity | Built-in (Proxy-based, fine-grained) | Custom (~150-300 lines, coarse-grained) |
| Build step | No (CDN) | No |
| Migration effort | Medium (incremental, one view at a time) | Low (refactor in place) |
| Learning curve | Low (HTML attributes, well-documented) | None for existing patterns; custom pattern to learn |
| Long-term maintenance | Low (framework handles reactivity) | Medium (custom code to maintain) |
| Debugging | Good (Alpine devtools, browser extensions) | Excellent (no abstraction layer) |
| Community | Active, 28K+ GitHub stars, extensive docs | N/A (custom code) |
| New contributor onboarding | Easy (well-known framework) | Harder (must learn custom patterns) |
| Risk of abandonment | Low (mature, widely adopted) | None (you own it) |
| XSS safety | `x-text` auto-escapes; `x-html` requires care | Manual `esc()` required everywhere |
| Partial DOM updates | Automatic (Alpine diffs DOM) | Manual (must track what changed) |
| View transitions | `x-transition` built-in | Must implement manually |
| Code reduction | ~30-40% less view code (estimated) | ~10-15% reduction (template literals only) |

## Decision

**Recommend: Option A — Alpine.js adoption.**

### Rationale

1. **The Ladder justification (ADR-0049)**: Alpine.js satisfies rung 4 ("Does an already-installed dependency solve it?"). While it's a new dependency, the alternative (Option B) requires writing ~200-300 lines of custom reactive code that will inevitably be a worse version of what Alpine provides. The Ladder says "boring over clever" — Alpine is the boring, proven solution. Writing a custom reactive framework is the clever solution.

2. **The jank problem is fundamentally about DOM reconciliation**: Manual DOM updates cannot efficiently handle the 3-second polling cycle in `session-list.js`. Alpine's Proxy-based reactivity tracks dependencies and updates only the DOM nodes that changed, eliminating the full `innerHTML` rebuild. This directly solves the user-reported jank.

3. **Incremental adoption matches the constraint**: Alpine can be added to `session-list.js` first (the worst offender for jank), then `settings.js`, then `session-detail.js`. Each migration is independent. The remaining views continue working vanilla until migrated.

4. **Python team learning curve**: Alpine's `x-data`, `x-show`, `x-on` are HTML attributes — the team already knows HTML. The mental model is "add attributes to existing elements" rather than "learn a new component system." This is the smallest conceptual jump from the current code.

5. **Window globals → Alpine.store()**: `Alpine.store('app', { ... })` provides a clean, reactive shared state that replaces both the `state.js` object and the window global pattern. Stores are accessible from any `x-data` scope via `$store.app`.

### Tradeoffs Accepted

| Tradeoff | Why Acceptable |
|----------|---------------|
| 15KB dependency | The custom reactive layer would be ~100-200 lines (~3-6KB). The 9-12KB delta buys mature, tested reactivity with devtools. |
| Two systems during migration | Migration is view-by-view. Each view is self-contained. Mixed state is temporary (weeks, not months). |
| Framework magic | Alpine is ~15KB — the entire runtime is readable in an afternoon. The "magic" is transparent. |
| The Ladder tension | Resolved by rung 4: "Does an already-installed dependency solve it?" Alpine is the dependency that solves reactivity. The custom alternative is more code, not less. |

## Consequences

### What Becomes Easier

- **DOM updates**: Change `state.currentTopic = 'new'` and the DOM updates automatically. No manual `render()` calls.
- **View switching**: `x-show="currentView === 'sessions'"` replaces the `showView()` function and the hidden-class toggling.
- **List rendering**: `x-for="session in sessions"` replaces the `renderSessionRow()` string concatenation loop.
- **Form binding**: `x-model="searchQuery"` replaces manual `addEventListener('input', ...)` + debounce logic.
- **Shared state**: `Alpine.store('app', { ... })` replaces `window.showSessions`, `window.showDetail`, etc.
- **View transitions**: `x-transition` provides smooth show/hide animations, reducing perceived jank.

### What Becomes Harder

- **Debugging reactive state**: When a DOM element doesn't update, the developer must understand Alpine's dependency tracking. Mitigation: Alpine devtools Chrome extension.
- **Removing the dependency later**: If Alpine is abandoned upstream, removing it requires reverting to vanilla patterns. Mitigation: Alpine is mature (28K+ stars, 5+ years), and the migration is incremental — each view can be un-migrated independently.
- **Mixed codebase during migration**: Some views use Alpine, some use vanilla. New contributors see two patterns. Mitigation: migration plan (below) limits the overlap period.

### Migration Plan

**Phase 1: Infrastructure (1 session)**
- Add Alpine.js CDN `<script>` tag to `demo.html`
- Create `Alpine.store('app', { ... })` with current state from `state.js`
- Verify Alpine loads and stores are accessible
- Do NOT change any existing code yet

**Phase 2: Session List (1-2 sessions) — highest jank impact**
- Add `x-data` to session list container
- Replace `renderSessionRow()` loop with `x-for`
- Replace `renderToolbar()` with Alpine-bound form elements
- Replace `bindToolbarEvents()` with `x-on:input`, `x-on:change`
- Remove polling-based full re-render; use Alpine reactivity for incremental updates
- This phase alone should eliminate the primary jank

**Phase 3: Settings View (1-2 sessions) — largest file**
- Migrate settings tabs one at a time (API Keys → Local Models → Scribe → Context Windows → Hardware)
- Replace `loadProviderList()` HTML generation with `x-for`
- Replace inline `onclick` handlers with `x-on:click`

**Phase 4: Remaining Views (1 session each)**
- Session detail, system log, agent panels, model picker
- Each view is self-contained migration

**Phase 5: Cleanup**
- Remove `state.js` (replaced by `Alpine.store`)
- Remove window global registrations
- Remove `showView()` function (replaced by `x-show`)
- Update `dashboard.js` entry point

### Rollback Strategy

Each phase is independent. If Phase 2 (session list) reveals problems:
1. Remove Alpine directives from session list HTML
2. Restore the vanilla `refreshSessionList()` function
3. Keep Alpine loaded (no harm) or remove the `<script>` tag
4. No other views are affected because migration is incremental

### Success Criteria

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Full DOM rebuilds per 3s | 1 (innerHTML) | 0 | Chrome DevTools Performance panel |
| Scroll position preserved across refreshes | No | Yes | Manual testing |
| Input focus preserved during typing in search | No (250ms debounce masks it) | Yes | Manual testing |
| Session list JS LOC | 402 | <250 (estimated) | `wc -l` |
| Settings JS LOC | 1,649 | <1,000 (estimated) | `wc -l` |
| Window global registrations | ~15 | 0 | `grep -r "window\." static/js/` |

## ADR References

- **ADR-0049** (Lazy Senior Dev / The Ladder) — Alpine.js justified under rung 4 (existing dependency solves it) and "boring over clever"
- **ADR-0001** (KodeHold Foundation) — design principles for dependency management

## Changelog

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-06-24 | Initial ADR — Frontend reactivity strategy for DeepResearch |
