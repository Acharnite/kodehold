# agentmemory Patches — v0.9.25

## Status: 8 ACTIVE PATCHES (1 legacy + 6 KG fixes + 1 summary quality)

| Patch | Purpose |
|-------|---------|
| `agentmemory-viewer-bind-0.9.25.patch` | Bypass AGENTMEMORY_SECRET requirement for `AGENTMEMORY_VIEWER_HOST=0.0.0.0` |
| `agentmemory-kg-stale-gc-0.9.25.patch` | **Fix 1** — Stale node/edge garbage collection (evict + standalone `mem::graph-gc`) |
| `agentmemory-kg-fuzzy-dedup-0.9.25.patch` | **Fix 2** — Fuzzy deduplication via Jaccard similarity during graph extraction |
| `agentmemory-kg-isolated-nodes-0.9.25.patch` | **Fix 3** — Delete isolated graph nodes (0 edges, 0 observation refs, >7 days old) |
| `agentmemory-kg-llm-validation-0.9.25.patch` | **Fix 4** — LLM output type validation in `parseGraphXml` |
| `agentmemory-kg-related-to-dedup-0.9.25.patch` | **Fix 5** — Skip redundant "related_to" edges when more specific type exists |
| `agentmemory-kg-locking-0.9.25.patch` | **Fix 6** — In-memory lock set to prevent concurrent extraction race conditions |
| `agentmemory-summary-quality-0.9.25.patch` | **Fix 7** — 3 summarization quality fixes: (1) `isPromptLeakage()` anti-pattern detection in `parseSummaryXml`, (2) qualityScore -80 penalty for prompt-leaked titles, (3) observationCount-based dedup (skip only when no new observations) |

## Apply (All Patches)

```bash
# Apply all 8 patches in order:
for p in agentmemory-viewer-bind-0.9.25.patch \
         agentmemory-kg-stale-gc-0.9.25.patch \
         agentmemory-kg-fuzzy-dedup-0.9.25.patch \
         agentmemory-kg-isolated-nodes-0.9.25.patch \
         agentmemory-kg-llm-validation-0.9.25.patch \
         agentmemory-kg-related-to-dedup-0.9.25.patch \
         agentmemory-kg-locking-0.9.25.patch \
         agentmemory-summary-quality-0.9.25.patch; do
  sudo patch -p1 -d /usr/local/lib/node_modules/@agentmemory/agentmemory/dist < patches/$p
done

# Restart the service:
systemctl --user restart agentmemory
```

## Patch Details

### Fix 1: `agentmemory-kg-stale-gc-0.9.25.patch`

**Problem:** When memories are superseded, graph nodes/edges are marked `stale = true`, and all queries filter them out, but they are NEVER deleted. Over time stale data accumulates.

**Solution:** Two changes:
1. In `registerEvictFunction` (mem::evict): after session/memory eviction, adds a GC pass that deletes all stale graph nodes and edges.
2. In `registerGraphFunction`: adds a new standalone `mem::graph-gc` function that can be called independently (e.g., via trigger or scheduled job).

Both operations record audit events for traceability.

### Fix 2: `agentmemory-kg-fuzzy-dedup-0.9.25.patch`

**Problem:** Node dedup in `mem::graph-extract` uses exact name matching only: `n.name === node.name`. This means "agentmemory" vs "agentmemory " (trailing space) creates 2 nodes. There were already 46 such duplicates.

**Solution:** Changes the node dedup `find()` to also use `jaccardSimilarity()` (already imported from schema module) with a 0.8 threshold. Same for edge dedup — matches edges with the same source/target node IDs and similar types.

### Fix 3: `agentmemory-kg-isolated-nodes-0.9.25.patch`

**Problem:** 693 nodes (43% at time of writing) have 0 edges — pure noise consuming memory and polluting the graph.

**Solution:** After stale cleanup in `mem::graph-gc`, scans all non-stale nodes and deletes those that:
- Have zero edges referencing them
- Have empty `sourceObservationIds` (no observation backing)
- Are older than 7 days

The 7-day grace period protects recently-created nodes that haven't yet accumulated edges.

### Fix 4: `agentmemory-kg-llm-validation-0.9.25.patch`

**Problem:** `parseGraphXml` accepts ANY `type` attribute from the LLM. The prompt says valid types are `file|function|concept|error|decision|pattern|library|person`, but the LLM sometimes regurgitates the entire type list as a type name (creating nodes like `type="file|function|concept|..."`).

**Solution:** Adds a `VALID_TYPES` Set and rejects any entity with an unrecognized type. This silently drops malformed XML entities instead of creating corrupt nodes.

### Fix 5: `agentmemory-kg-related-to-dedup-0.9.25.patch`

**Problem:** 571/1162 edges (49%) are type "related_to" — the generic fallback. When both a specific edge (e.g., "uses", "imports") and "related_to" exist between the same two nodes, the "related_to" is redundant noise.

**Solution:** Two changes:
1. In `mem::graph-extract` edge insertion: before inserting a "related_to" edge, checks if a non-"related_to" edge already exists between the same source/target pair. If yes, skips the "related_to".
2. In `mem::graph-gc`: scans all edge pairs for cases where both a "related_to" and a more specific edge exist. Deletes the redundant "related_to".

### Fix 6: `agentmemory-kg-locking-0.9.25.patch`

**Problem:** `event::session::stopped` fires `mem::graph-extract` as a void trigger. If two sessions stop simultaneously, both extraction calls load the same `existingNodes`/`existingEdges` lists and can create duplicate nodes because they can't see each other's pending writes.

**Solution:** Adds an in-memory `Set`-based lock that prevents concurrent extractions for the same session. Uses `try/finally` to ensure the lock is always released. If a lock is contended, the second trigger returns early (the first extraction will cover the observations).

### Fix 7: `agentmemory-summary-quality-0.9.25.patch`

**Problem:** Three quality issues in session summarization:
1. **Prompt-leakage:** ~3-4% of session summaries have titles containing raw prompt text (e.g., "Short session title (max 100 chars)") because the LLM regurgitated the prompt rather than generating content. The `parseSummaryXml` regex-based parser happily extracts `Short session title (max 100 chars)` as the title since it matches the `<title>` tag.
2. **qualityScore unreliable:** The structural-only scoring in `scoreSummary()` gives perfect 100 scores to prompt-leaked summaries because the regurgitated text is long enough to pass all length checks.
3. **Duplicate summaries per session (observationCount-fixed):** Three independent triggers each call `/summarize`. Initial dedup was unconditional (skipped if ANY summary existed), which prevented new observations from being summarized. Fixed: compare `existingSummary.observationCount >= compressed.length` — skips only when no new observations.

**Solution:** Three changes:
1. Added `isPromptLeakage(summary)` function that checks 6 anti-patterns in title (starts with backtick, contains "Short session title", "max 100 chars", structural instruction patterns, "Output EXACTLY", or >80 chars with 2+ structural keywords). Called in `parseSummaryXml` before returning — returns `null` on detection, triggering the retry loop.
2. Added anti-pattern penalty in `scoreSummary()`: -80 points (clamped to 0) for prompt-leaked titles.
3. Added deduplication check in `registerSummarizeFunction`: checks `KV.summaries` for existing summary before running LLM. Returns existing summary if found.

**Status:** Applied to installed agentmemory. Syntax verified, service running.

**File target:** The patch targets `src-fQOMXeCp.mjs` — the runtime chunk file that `cli.mjs` imports. This is the actual file loaded by the service, NOT `index.mjs` (which is dead code).

**Manual apply:**
```bash
sudo patch -p1 -d /usr/local/lib/node_modules/@agentmemory/agentmemory/dist < patches/agentmemory-summary-quality-0.9.25.patch
```

## Current .env Settings

```
AGENTMEMORY_VIEWER_HOST=0.0.0.0
VIEWER_ALLOWED_HOSTS="localhost,localhost:3113,127.0.0.1:3113,192.168.1.176:3113,am.server.int:3113"
```

## Verification

```bash
# Check service is running:
systemctl --user status agentmemory

# Check graph stats:
curl -s http://localhost:3111/agentmemory/graph/stats | python3 -m json.tool

# Trigger manual graph GC:
curl -s -X POST http://localhost:3111/agentmemory/evict \
  -H 'Content-Type: application/json' \
  -d '{"dryRun":false}' | python3 -m json.tool

# Verify patch is active (e.g., Fix 4 corrupted type guard):
grep -n 'VALID_TYPES' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-fQOMXeCp.mjs
# Expect: line(s) with "const VALID_TYPES"
```

## Historical Reference — v0.9.24 Archive

All patches that applied to v0.9.24 are preserved in `../patches-v0.9.24/`:

| File | Purpose | v0.9.25 resolution |
|------|---------|---------------------|
| `agentmemory-viewer-bind.patch` | Viewer bind `127.0.0.1` → `0.0.0.0` | Built into .env (`AGENTMEMORY_VIEWER_HOST=0.0.0.0`) |
| `agentmemory-triggervoid-to-trigger.patch` | `triggerVoid` → `trigger()` migration | Upstream PR #773 |
| `agentmemory-summary-xml-parse.patch` | XML markdown fence stripping (dead code ref) | Upstream PR #791 |
| `agentmemory-summary-xml-parse-src.patch` | Same fix for real runtime file | Upstream PR #791 |
| `agentmemory-capture-project-detection.patch` | Plugin reference (applied elsewhere) | See note below |
| `agentmemory-merged.patch` + `.bak` | Combined patch script (v0.9.24 only) | — |

## Other Local Modifications (Not Dist Patches)

- **Capture plugin project detection fix**: Applied directly to
  `~/.config/opencode/plugins/agentmemory-capture.ts`. Not a dist patch —
  it's a plugin modification that lives outside the agentmemory package.

## Post-Upgrade Verification

```bash
grep -o '"0\.9\.25"' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/version-*.mjs
# or check the running service:
systemctl --user status agentmemory
```

To verify the viewer-bind patch is active:

```bash
grep -n 'if (false)' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/index.mjs
# Expect: line(s) with "if (false) {"
```

To verify the KG patches are active:

```bash
grep -n 'VALID_TYPES' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-fQOMXeCp.mjs
# Expect: line with "const VALID_TYPES"
grep -n 'jaccardSimilarity(n.name' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-fQOMXeCp.mjs
# Expect: fuzzy dedup logic
grep -n 'mem::graph-gc' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-fQOMXeCp.mjs
# Expect: standalone GC function
```
