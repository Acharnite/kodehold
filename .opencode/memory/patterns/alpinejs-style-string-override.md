---
type: pattern
project: krypto-agent
concepts: alpinejs, css, frontend-bug
created: 2026-07-03
---

# Alpine.js `:style` String Override Bug

## Problem
When Alpine.js `:style` directive returns a **plain string**, it **replaces the entire `style` attribute** instead of merging with existing inline styles:

```html
<!-- BAD: :style="'text-align:right'" replaces ALL inline styles -->
<th x-bind:style="'text-align:right'" style="padding:8px">
  <!-- Result: only text-align:right survives, padding is lost -->
</th>
```

This is because Alpine.js treats a string return value from `:style` as a direct assignment to `element.style.cssText`, which overwrites everything.

## Fix
Use the **object syntax** for `:style` in Alpine.js:

```html
<!-- GOOD: :style="{textAlign: 'right'}" merges with existing styles -->
<th x-bind:style="{textAlign: 'right'}" style="padding:8px">
  <!-- Result: both text-align:right AND padding:8px survive -->
</th>
```

Or use CSS classes instead of inline styles.

## Lesson
Always use `:style="{property: value}"` object syntax in Alpine.js, never `:style="'string'"`. The string form is destructive to other inline styles.
