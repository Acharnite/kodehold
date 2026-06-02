# agentmemory Patches

This directory contains patches applied to the agentmemory v0.9.24
npm-global installation at `/usr/local/lib/node_modules/@agentmemory/agentmemory/`.

## Critical File Architecture

The agentmemory CLI entry point is `/usr/local/bin/agentmemory`, which
symlinks to `cli.mjs`. **`cli.mjs` imports `src-B8J9Exum.mjs` at runtime**,
NOT `index.mjs`. The `index.mjs` file is effectively dead code — it exists in
the dist directory but is never loaded by the running service.

```
cli.mjs  ──imports──>  src-B8J9Exum.mjs   (THE REAL RUNTIME)
                        (index.mjs)          (DEAD CODE — never loaded)
```

**This means:** Any patch that only targets `index.mjs` has NO EFFECT.
Both files must be patched identically, or just `src-B8J9Exum.mjs`.

## File Map

| File | What it patches | Why |
|------|----------------|-----|
| `agentmemory-viewer-bind.patch` | `index.mjs` (reference) | View server bind `127.0.0.1` → `0.0.0.0` |
| | `src-B8J9Exum.mjs` (real target) | Same change via merged patch |
| `agentmemory-triggervoid-to-trigger.patch` | `index.mjs` (reference) | Deprecated `triggerVoid` → new `trigger()` API |
| | `src-B8J9Exum.mjs` (real target) | Same change via merged patch |
| `agentmemory-capture-project-detection.patch` | `agentmemory-capture.ts` plugin | Fix project path detection |
| `agentmemory-summary-xml-parse.patch` | `index.mjs` (DEAD CODE) | Summary XML fix — kept for reference only |
| `agentmemory-summary-xml-parse-src.patch` | `src-B8J9Exum.mjs` (REAL RUNTIME) | Summary XML fix — the ONE that matters |
| `agentmemory-merged.patch` | ALL files above | Single bash+patch script applying everything |

## How to Use

### Apply ALL patches (recommended)
```bash
sudo bash patches/agentmemory-merged.patch
systemctl --user restart agentmemory
```

### Apply individual patch (src-B8J9Exum.mjs only)
```bash
sudo patch -p1 -d /usr/local/lib/node_modules/@agentmemory/agentmemory/dist \
  < patches/agentmemory-summary-xml-parse-src.patch
systemctl --user restart agentmemory
```

### Rollback
```bash
sudo bash patches/agentmemory-merged.patch --reverse
systemctl --user restart agentmemory
```

## After npm Upgrade
`npm install -g @agentmemory/agentmemory` overwrites ALL files in `dist/`.
Reapply patches afterwards:
```bash
npm install -g @agentmemory/agentmemory
sudo bash patches/agentmemory-merged.patch
systemctl --user restart agentmemory
```

## Patch Discovery History

1. **2026-05-31**: Port 3113 bind hotfix — patched `index.mjs` only
2. **2026-06-01** (morning): triggerVoid→trigger migration — patched both
   `index.mjs` and `src-B8J9Exum.mjs` after discovering both files
3. **2026-06-01** (afternoon): Migrated standalone patches into merged
   `agentmemory-merged.patch` with combined sections
4. **2026-06-02**: **CRITICAL DISCOVERY** — `cli.mjs` imports
   `src-B8J9Exum.mjs`, NOT `index.mjs`. Our `index.mjs`-only summary XML
   parse patch was ineffective. Created `agentmemory-summary-xml-parse-src.patch`
   targeting the real runtime file and manually patched the live file.
