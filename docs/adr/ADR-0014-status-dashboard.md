# ADR-0014: Status Dashboard — KodeHold Project Overview

## Status

Proposed

## Context

KodeHold manages multiple projects under `workspaces/<name>/`, each with its own lifecycle state, design documents, ADRs, TODO lists, and ICM memory. As the number of managed projects grows (currently: lib-validate, radarr-lang-router), it becomes difficult to get a quick overview of:

- What projects exist and what state they are in (INIT / ACTIVE / REVIEW / CLOSED / REOPEN)
- Whether each project's design document is up-to-date and reviewed
- How many ADRs have been written per project
- What portion of the TODO is complete
- When the project last saw activity (git commits, state transitions)
- How many tokens have been consumed per project (from OpenCode DB)

Without a dashboard, answering these questions requires manually inspecting each workspace directory — reading `.kodehold-state`, counting ADR files, parsing TODO.md for completion markers, running git log, and querying ICM. This does not scale.

The key forces are:

1. **No backend infrastructure** — KodeHold has no server runtime. Any solution must be zero-infrastructure.
2. **Single source of truth** — The filesystem *is* the database. State files, design docs, ADRs, and TODO files already contain the canonical data.
3. **Token-conscious** — The dashboard generation itself should not consume LLM tokens. A deterministic script is preferred over an agent-based approach.
4. **Low maintenance** — Once written, the dashboard should mostly take care of itself. Adding a new project should automatically update the view.
5. **Portable** — The dashboard should work offline (local file) but optionally be publishable to GitHub Pages.
6. **Reusable pattern** — The data aggregation approach could later be reused by other KodeHold tooling (e.g., audit reports, shipping gate status).

## Decision

We implement a **deterministic script** that generates a **single, self-contained static HTML page** (`docs/dashboard/index.html`). The page is regenerated on demand. Each project is a row in a table, with visual state badges and summary metrics.

### Language Choice — To Be Investigated

This ADR remains **Proposed** until the generator language is finalized and all `TBD` entries in this document are replaced with explicit decisions.

The generator language is **not yet decided**. Unlike existing KodeHold scripts (`gate.sh`, `workspace.sh`, `ship.sh`) which are simple shell orchestration, the dashboard script involves:

- Parsing structured data (JSON from `.catalog`, key=value from `.kodehold-state`, Markdown from design docs, YAML from configs)
- Calculating completion percentages from TODO.md checkboxes
- Constructing HTML with inline CSS (string building)
- Optionally querying SQLite (`opencode.db`) for token data
- Resilient error handling across diverse file states

Three candidates will be evaluated:

| Language | Strengths | Concerns |
|----------|-----------|----------|
| **Bash** (with jq/awk) | Zero new dependencies, matches KodeHold pattern, fast for simple text processing | Fragile string handling, painful HTML construction, no JSON library beyond jq, error handling is verbose |
| **Python 3** | Built-in JSON/YAML/HTML libs, rich error handling, readable for complex logic, already used in KodeHold tests | Adds `.venv` dependency (already available at `.venv/bin/python3`), slightly slower startup |
| **Rust** | Fastest execution, strong typing catches errors, single binary output | Longer development time, not yet in KodeHold toolchain, compilation overhead for a script that runs rarely |

**Recommended evaluation:** Build a quick prototype in Bash first, assess where it becomes painful, then decide whether to port to Python or Rust. This decision will be recorded as an update to this ADR.

### Architecture

| Dimension | Decision | Rationale |
|-----------|----------|-----------|
| Generator | TBD — Bash, Python, or Rust (see language evaluation above) | Script-based, deterministic, zero infrastructure. Final language chosen after prototyping. |
| Output | Single self-contained HTML file | No routing, no navigation, no pagination. Single page = zero infrastructure, works offline, easy to serve. CSS and JS inline. |
| Styling | Inline CSS, no frameworks | Keeps the file portable. Add a CDN-linked CSS framework (e.g., Pico CSS or Water.css) if visual polish is needed later — that is still zero build step. |
| Update trigger | On-demand (`bash scripts/dashboard.sh`) | Matches existing KodeHold script pattern. No watchers, no cron, no CI trigger. The Director can regenerate before team meetings (ADR-0011) or on request. |
| Serving | Local `file://` or GitHub Pages via CI | Primary use is local. GitHub Pages is optional via a CI workflow that commits the generated page to `gh-pages` branch. |

### Data Sources

Every data point is extracted from the canonical filesystem source — no derived state files, no intermediate caches.

| Data Point | Source | Extraction Method |
|-----------|--------|-------------------|
| Project list | `workspaces/.catalog` (JSON) | `jq 'keys'` to enumerate projects |
| Lifecycle state | `<workspace>/.kodehold-state` (key=value) | `grep ^STATE=` + `cut -d= -f2` |
| Adopted flag | `<workspace>/.kodehold-state` | `grep ^ADOPTED=` |
| Design doc version | `<workspace>/docs/design/README.md` | `grep '\*\*Version:\*\*'` + extract version string |
| Design doc status | `<workspace>/docs/design/README.md` | `grep '\*\*Status:\*\*'` |
| Last reviewed | `<workspace>/docs/design/README.md` | `grep '\*\*Last Reviewed:\*\*'` |
| ADR count | `<workspace>/docs/adr/` | Count `ADR-*.md` files (exclude README.md) |
| TODO completion | `<workspace>/TODO.md` | Count `- [x]` vs `- [ ]` lines for % completion |
| Last git commit | `<workspace>/.git` | `git -C <workspace> log -1 --format=%ci` (ISO 8601 date) |
| Last state transition | `workspaces/.catalog` | `jq '.<project>.updated'` — catalog's `updated` field |
| Token usage | `~/.local/share/opencode/opencode.db` (SQLite) | Optional: `sqlite3` query for per-session token counts, keyed by project name in metadata |

### Optional: OpenCode Token Data

The OpenCode token database (`opencode.db`) is a SQLite file. It can be queried for session-level token data. The dashboard script includes a `--tokens` flag that enables the query:

```bash
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT json_extract(metadata, '$.project'), sum(prompt_tokens + completion_tokens)
   FROM sessions
   WHERE metadata IS NOT NULL
   GROUP BY json_extract(metadata, '$.project')"
```

This is optional because:
- The database path varies by platform/setup
- The query may be slow on large DBs
- Not all sessions have project metadata
- It requires `sqlite3` CLI (not guaranteed on all systems)

The dashboard shows a "Token data unavailable" row when `--tokens` is not passed or `sqlite3` is missing.

### Output Layout

The generated HTML page has three sections:

1. **Header** — "KodeHold Dashboard", generation timestamp, total project count
2. **Summary bar** — Counts per state (e.g., "3 ACTIVE · 2 CLOSED · 1 INIT")
3. **Project table** — One row per project with columns:

| Column | Example |
|--------|---------|
| Project | `lib-validate` |
| State badge | `CLOSED` (colored: green, blue, yellow, gray per state) |
| Design Doc | `v0.2 · Active · Reviewed 2026-05-26` |
| ADRs | `2` |
| TODO | `80%` (16/20) with a visual progress bar |
| Last Commit | `2026-05-26 14:30` (relative: "2 days ago") |
| Tokens | `142,350` (if `--tokens` flag passed) |

### Color Scheme for States

| State | Badge Color | Rationale |
|-------|-------------|-----------|
| INIT | `#94a3b8` (slate) | Neutral — not started |
| ACTIVE | `#3b82f6` (blue) | In progress |
| REVIEW | `#eab308` (yellow) | Pending decision |
| CLOSED | `#22c55e` (green) | Complete |
| REOPEN | `#f97316` (orange) | Reactivated |

### File Locations

- **Generator script**: `scripts/dashboard.sh` (new file, executable)
- **Generated output**: `docs/dashboard/index.html` (new file, gitignored or committed per preference)
- **Dashboard generator design doc**: This ADR serves as the design record — no separate design doc needed for a script

### Error Handling

The script is designed to be resilient to missing data:

- If a workspace lacks `docs/design/README.md` → show "N/A" for design doc fields
- If a workspace lacks `TODO.md` → show "—" for completion rate
- If the workspace git repo has no commits → show "No commits"
- If `--tokens` is requested but `sqlite3` is missing → show "Requires sqlite3"
- If a workspace directory is missing from disk but present in `.catalog` → show "⚠ Missing" with red badge

## Consequences

### Positive

- **Zero infrastructure** — No server, no database, no build step. Works offline. Open in any browser.
- **Scales with project count** — Adding a new workspace project via `workspace.sh init` or `workspace.sh adopt` automatically appears in the dashboard the next time the script runs.
- **Deterministic** — The same script produces the same output given the same filesystem state. No LLM token cost. CI-reproducible. Language choice (Bash/Python/Rust) affects robustness but not determinism.
- **Reusable extraction** — The awk/jq/git patterns in the script can be reused by other KodeHold tooling (e.g., a `scripts/audit.sh` for pre-shipping gate checks).
- **Low maintenance** — No framework updates, no dependency bumps, no database migrations. Filesystem schema changes (e.g., new fields in `.kodehold-state`) require a script update, but such changes are rare and would be coordinated through ADRs anyway.
- **Visible by default** — Project health is no longer hidden inside workspace directories. Everyone (Director, FLS, user) can see the full picture at a glance.

### Negative

- **Not real-time** — The page is a snapshot at generation time. Concurrent changes (e.g., a state transition happening while another operation runs) are not reflected until the next `bash scripts/dashboard.sh` invocation.
- **No interactivity** — The HTML has no JavaScript beyond what is inlined. Sorting, filtering, or click-to-expand would require adding JS. This is a deliberate choice to keep it simple; JS can be added later if needed.
- **OpenCode token query is best-effort** — The token data depends on project metadata being set in OpenCode sessions, which is not yet standard practice. The column will often be empty.
- **Script duplication** — The dashboard script duplicates file-parsing logic that also exists in `scripts/gate.sh` and `scripts/workspace.sh`. If `.kodehold-state` format changes, three scripts may need updating. Mitigation: if the parsing grows more complex, extract a shared `scripts/lib/state.sh` library.
- **Large Git history** — If committed regularly, the generated HTML file will bloat the git history. Mitigation: either `.gitignore` `docs/dashboard/index.html` and generate fresh, or commit only at release boundaries.

### Neutral

- **Design doc fields are free-form** — The script assumes `**Version:**`, `**Status:**`, `**Last Reviewed:**` lines follow the convention in `docs/design/README.md` template. Projects that deviate from the template will show incorrect or missing data. This is acceptable because design doc discipline is enforced by the Architects team.
- **GitHub Pages is optional** — The script does not depend on GitHub. A separate CI workflow (`.github/workflows/dashboard.yml`) can be added to auto-build and deploy to `gh-pages`, but the core feature works without it.

## Implementation Plan

### Phase 0: Language Evaluation (1 session)

1. **Prototype in Bash** — Build a minimal proof-of-concept that enumerates projects, extracts state, and outputs a simple HTML table. Assess where Bash becomes painful (HTML construction, error handling, SQLite queries)
2. **Evaluate Python alternative** — If Bash proves fragile, build the same prototype in Python using `json`, `html`, and `sqlite3` stdlib modules
3. **Decide and update this ADR** — Record the final language choice and rationale

### Phase 1: Core Script (1 session)

1. **Create generator script** in the chosen language
2. **Implement project enumeration** — Read `workspaces/.catalog`, iterate over project keys
3. **Implement state extraction** — Parse `<workspace>/.kodehold-state` for `STATE` and `ADOPTED` fields
4. **Implement design doc parsing** — Extract Version, Status, Last Reviewed from `docs/design/README.md`
5. **Implement ADR count** — Count `ADR-*.md` files in `docs/adr/`
6. **Implement TODO completion** — Count `[x]` vs `[ ]` items in `TODO.md`, compute percentage
7. **Implement git activity** — `git -C <workspace> log -1 --format=%ci` for last commit date
8. **Generate HTML** — Emit a complete, styled HTML document with CSS and inline table

### Phase 2: OpenCode Token Integration (1 session)

9. **Add `--tokens` flag** — When passed, query `opencode.db` for per-project token sums
10. **Handle errors** — Missing `sqlite3`, missing project metadata, empty DB

### Phase 3: Polish and Verification

11. **Add summary bar** — Aggregate counts per state at the top of the page
12. **Add relative timestamps** — Convert ISO dates to "X days ago" using simple date arithmetic or static mapping
13. **Test on all workspaces** — Run against current lib-validate and radarr-lang-router; verify all columns
14. **Add edge case handling** — Missing directories, malformed state files, empty TODO.md
15. **Update `.gitignore`** — Optionally add `docs/dashboard/` if we choose not to commit generated output

### Phase 4: Optional — GitHub Pages Deployment (not required for acceptance)

16. **Create** `.github/workflows/dashboard.yml` — Trigger on push to main, run script, deploy to `gh-pages`
17. **Configure GitHub Pages** — Source from `gh-pages` branch, `/docs` directory
18. **Add badge** — "📊 Dashboard" link in README.md

### Effort Estimate

| Phase | Tasks | Estimated sessions |
|-------|-------|-------------------|
| Phase 0 | Language evaluation (Bash vs Python vs Rust) | 1 session (Architects + Engineers) |
| Phase 1 | Core script + HTML | 1 session (Engineers) |
| Phase 2 | Token integration | 1 session (Engineers) |
| Phase 3 | Polish + edge cases | 0.5 session (Engineers) |
| Phase 4 | GitHub Pages (optional) | 0.5 session (Engineers) |

Total: ~4 sessions (3.5 mandatory + 0.5 optional)

### Future Considerations

- **JavaScript sorting** — Add optional column-sorting via ~20 lines of vanilla JS if users request it
- **State transition timeline** — Show a mini timeline per project (e.g., "INIT → ACTIVE on 2026-05-25") by reading `.kodehold-state` change history from git
- **ICM memory count** — Query ICM database for memory counts per project (requires ICM DB schema stability)
- **Flask/Live server** — If real-time monitoring is ever needed, the script's data extraction is trivially wrappable in a lightweight HTTP server (Flask or even `python -m http.server` with a cron-regenerated HTML file)

---

*Note: This ADR was generated by the Architects team. The implementation will be delegated to Engineers via the Director.*
