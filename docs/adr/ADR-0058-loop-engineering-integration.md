# ADR-0058: Loop Engineering Integration & Token Budget Protocol v2

## Status

Accepted

## Context

### The Problem

KodeHold operates as a structured software organization — Director orchestrates tasks, Architects design, Engineers implement, Reviewers validate. But the system is **entirely human-triggered**. Every task delegation, every session start, every review cycle requires a human to prompt the Director. There is no autonomous scheduling, no unattended maintenance, and no systematic feedback loop between completed work and new work.

Meanwhile, the **Loop Engineering** framework (cobusgreyling/loop-engineering, 8.9k stars) provides a mature pattern for designing autonomous agent systems: "Stop prompting. Design the loop. Get a score." Loop Engineering's five building blocks — Scheduling, Worktrees, Skills, MCP Connectors, Sub-agents + Memory/State — map directly onto KodeHold's existing architecture. KodeHold already has 4 of 5 building blocks implemented; it is missing only **Scheduling** and **Worktrees**.

### KodeHold vs Loop Engineering Mapping

| Loop Building Block | KodeHold Status | Detail |
|---------------------|----------------|--------|
| **Scheduling** | MISSING | No cron/systemd, no `opencode run` integration |
| **Worktrees** | MISSING | No git worktree isolation for parallel work |
| **Skills** | PRESENT | `.opencode/skills/` — 7 skills loaded on-demand |
| **MCP Connectors** | PRESENT | Graphify, opencode-mem, GitHub MCP servers |
| **Sub-agents + Memory/State** | PRESENT | 6 teams, Director orchestrator, `.kodehold-state`, opencode-mem |

### Loop Engineering Toolchain

The loop-engineering ecosystem provides structured tooling:

| Tool | Purpose | KodeHold Equivalent |
|------|---------|-------------------|
| `loop-init` | Scaffold new loop | `workspace.sh init` |
| `loop-audit` | Loop Readiness Score (0-100) | gate.py (binary pass/fail, no score) |
| `loop-cost` | Token estimation per run | `token-usage.sh` (referenced, not implemented) |
| `loop-sync` | Drift detection (state vs doc) | Manual ADR/design doc review |
| `loop-gate` | Declarative gate enforcement | gate.py (hardcoded Python) |
| `loop-context` | Memory manager | opencode-mem (via MCP) |
| `loop-worktree` | Isolated git worktrees | None |

### Why Now

ADR-0007 (Token Optimization Strategy) was written in May 2025 during INIT phase. It defines a solid vocabulary-level optimization strategy (English-only, chunking, tiered loading) and per-phase token budgets. However, it is **entirely manual** — budgets are guidelines, not enforced constraints. No automation budget exists. No kill switch. No per-automation-run caps.

KodeHold has evolved significantly since ADR-0007:
- **ADR-0051**: opencode-mem replaced file-based memory → token savings
- **ADR-0054**: Graphify replaced opencode-rag for code retrieval → deterministic, token-efficient queries
- **ADR-0057**: Migrated file memory to opencode-mem, removed checkpoint/compression protocols → leaner context loading
- **ADR-0049**: The Ladder coding philosophy → less code, fewer tokens

The system is now mature enough for automation. Loop Engineering provides the missing operational layer.

### Key Forces

1. KodeHold has 4 of 5 loop-engineering building blocks already — integration is additive, not replacement
2. Automation WITHOUT budget controls risks runaway token consumption
3. Automation WITHOUT drift detection risks executing against stale designs
4. Gate.py is 771 lines of hardcoded Python — declarative gates would be more maintainable and loop-gate compatible
5. Per-automation token caps and a kill switch are essential safety mechanisms for unattended operation
6. KodeHold's `.kodehold-state` is machine-readable but not human-friendly for loop state tracking

## Decision

### 1. Adopt Loop Engineering as KodeHold's Operational Framework

KodeHold IS loop engineering with a strong team metaphor. The missing pieces are the **automation layer** (scheduling) and **isolation layer** (worktrees). This ADR defines a three-phase integration roadmap.

**Phase definition principle:** Each phase must produce a self-contained, independently-usable result. No phase should depend on a future phase for completeness.

### 2. Three-Phase Integration Roadmap

#### Phase 1: Foundation (Current — Immediate)

**Goal:** Establish baseline metrics and standards. Zero automation — manual runs only.

| Milestone | What | Priority |
|-----------|------|----------|
| **P1.1** Run `loop-audit` on KodeHold | Establish baseline Loop Ready Score. Document gaps. Target ≥80 before Phase 2. Note: `loop-audit` CLI availability should be validated (`npx @cobusgreyling/loop-audit --version`) before this milestone begins — do not assume the tool works without verification. | MUST |
| **P1.2** Write `config/gate.yaml` | Declarative gate definitions (schemas, markers, checks). Compatible with loop-gate. Does NOT replace gate.py yet — runs alongside it. | MUST |
| **P1.3** Implement `scripts/token_usage.py` | Query OpenCode SQLite DB for per-team token counts. JSON output. Replaces the referenced-but-not-implemented `token-usage.sh`. Uses `search_memories(query="session_token", tags=["loop_cost"])` for historical tracking. | MUST |
| **P1.4** Token Budget Protocol v2 | Modernize ADR-0007 budgets (see §6 below). | MUST |
| **P1.5** Write `STATE.md` | Human-readable loop state file alongside `.kodehold-state`. Documents active loops, last run times, health status. Updated by Scribes after each loop iteration. | SHOULD |

**Phase 1 completion gate:** Loop Ready Score documented + gate.yaml validated + token_usage.py functional.

#### Phase 2: Automation (Requires Phase 1 Complete)

**Goal:** L1 autonomous loops (report-only, no unattended writes). Cron-based.

| Milestone | What | Autonomy |
|-----------|------|----------|
| **P2.1** Daily Triage Loop | Cron job runs `opencode run` with a triage prompt every morning. Agent reads recent `search_memories`, checks for stale PRs, failing CI, uncommitted ADRs. Produces a report (stored via `add_memory` and appended to `loop-run-log.md`). No automated fixes. | L1 (report-only) |
| **P2.2** PR Babysitter Loop | Cron job checks open PRs → updates stale PRs, flags merge conflicts, notifies if review >24h pending. | L1 (report-only) |
| **P2.3** loop-sync Drift Detection | Weekly cron job compares design doc ADR index vs actual files, state file vs marker files, TODO.md vs completed ADRs. Reports drift without fixing. | L1 (report-only) |
| **P2.4** Token Budget Monitoring | Director runs `token_usage.py` before each delegation. 80% → warning, 100% → alert + suggest context compression. Logged to `add_memory(tags=["loop_cost"])`. | N/A (manual gate) |

**Phase 2 completion gate:** Three loops running for 7 consecutive weekdays with at least one meaningful finding or an explicit "no issues found" report per loop per day (empty runs do not count as successful). Loop Ready Score re-evaluated.

#### Phase 3: Deep Integration (Requires Phase 2 Complete)

| Milestone | What | Autonomy |
|-----------|------|----------|
| **P3.1** Worktree Isolation | Use `git worktree` for Engineer isolation. Each Engineer task gets a clean worktree. Requires separate ADR (detailed scope: worktree lifecycle, cleanup, conflict handling). | N/A (isolation only) |
| **P3.2** Goal Mode Skill | `.opencode/skills/goal-mode/SKILL.md` — defines "run until condition met" patterns. Uses prospective memory for tracking. Loop exits when condition satisfied, budget exhausted, or human-gate reached. | L2 (assisted) |
| **P3.3** Declarative Gate Migration | gate.py fully replaced by `config/gate.yaml` + loop-gate validation. gate.py becomes a thin wrapper. | N/A (infrastructure) |

**Phase 3 completion gate:** Worktree ADR accepted, Goal Mode skill functional.

### 3. Gate Definition: Declarative gate.yaml

Migrate from hardcoded gate.py (771 lines) to declarative `config/gate.yaml`:

```yaml
# config/gate.yaml — Declarative gate definitions
# Compatible with loop-gate. gate.py wraps this file.

version: "1.0"

transitions:
  INIT_TO_ACTIVE:
    markers_required:
      - .design_reviewed
      - .second_opinion_done
    markers_cleanup:
      - .design_reviewed
      - .second_opinion_done
    checks:
      design_doc_exists: { type: file_exists, path: "docs/design/README.md" }
      design_doc_active: { type: grep, path: "docs/design/README.md", pattern: "Status.*Active" }
      design_sections: { type: sections, path: "docs/design/README.md", required: [summary] }
      adr_dir_exists: { type: dir_exists, path: "docs/adr" }
      adr_count_min: { type: file_count, path: "docs/adr", pattern: "ADR-*.md", min: 1 }
      adr_index_exists: { type: file_exists, path: "docs/adr/README.md" }
    interactive: true

  ACTIVE_TO_REVIEW:
    markers_required:
      - .testers_done
      - .code_reviewed
    markers_cleanup:
      - .testers_done
      - .code_reviewed
    checks:
      todo_exists: { type: file_exists, path: "TODO.md", warn_only: true }
      tests_pass: { type: command, run: "python3 scripts/gate.py --tests-only" }
      review_commits: { type: git_log_recent, pattern: "review|reviewed|approve", warn_only: true }
```

**Migration strategy:** gate.yaml runs alongside gate.py (dual validation, assert parity). After Phase 3.3, gate.py becomes a thin wrapper that parses gate.yaml.

### 4. Scheduling: Cron + opencode run

All scheduled loops use `crontab` entries invoking `opencode run` through a wrapper script. **Note:** The `opencode run --prompt` CLI syntax should be verified against the current opencode version before crontab deployment — if `--prompt` is not supported, fall back to `--file` with a prompt file. This validation is part of Phase 1.1 (loop-audit baseline).

#### 4.1 Cron Wrapper Script

Each crontab entry wraps `opencode run` in a shell script that:
- Logs start time, exit code, and duration to `loop-run-log.md`
- Creates a `.loop_error` marker on non-zero exit for FLS triage
- Ensures consistent logging even when `opencode` itself fails
- Pipes all output to `loop-run-log.md` as a plain-text fallback for `add_memory`

Example wrapper: `scripts/loop-run.sh`:

```bash
#!/bin/bash
# scripts/loop-run.sh — Wrapper for scheduled opencode loops
# Usage: scripts/loop-run.sh <loop-name> "<prompt>"

LOOP_NAME="$1"
PROMPT="$2"
START_TIME=$(date -Iseconds)
EXIT_CODE=0

echo "## $LOOP_NAME — $START_TIME" >> loop-run-log.md
opencode run --prompt "$PROMPT" 2>&1 | tee -a loop-run-log.md
EXIT_CODE=${PIPESTATUS[0]}

DURATION=$(( $(date +%s) - $(date -d "$START_TIME" +%s) ))
echo "**Exit code:** $EXIT_CODE | **Duration:** ${DURATION}s" >> loop-run-log.md
echo "" >> loop-run-log.md

if [ $EXIT_CODE -ne 0 ]; then
    touch .loop_error
    echo "**⚠️ Non-zero exit — .loop_error marker created for FLS triage**" >> loop-run-log.md
fi

exit $EXIT_CODE
```

Updated crontab entries using the wrapper:

```bash
# Daily Triage Loop — every weekday at 08:00
0 8 * * 1-5 cd /path/to/kodehold && scripts/loop-run.sh daily-triage "Run daily triage: check for stale PRs, failing CI, uncommitted ADRs. Report only, no fixes. Store report via add_memory(scope=project, tags=['loop_report','daily_triage'])"

# PR Babysitter — every 4 hours during working hours
0 8,12,16 * * 1-5 cd /path/to/kodehold && scripts/loop-run.sh pr-babysitter "Run PR babysitter: check open PRs for staleness, merge conflicts, pending reviews >24h. Report only."

# Drift Detection — every Sunday at 10:00
0 10 * * 0 cd /path/to/kodehold && scripts/loop-run.sh drift-detection "Run loop-sync drift detection: compare design doc ADR index vs actual files, state file vs marker files, TODO.md vs completed ADRs. Report drift, do not fix."
```

All loops use L1 autonomy (report-only) initially. L2/L3 gated behind proven reliability.

### 5. Worktree Isolation

Engineer tasks use `git worktree` for isolation. Each task creates a new worktree, works in it, and the result is merged back. This prevents in-progress work from interfering with other tasks.

**Requires separate ADR** (scope too large for this ADR). Key considerations:
- Worktree lifecycle: create → work → commit → merge → cleanup
- Concurrent worktree limit (disk space, git index locks)
- Conflict resolution strategy when multiple worktrees modify same files
- Integration with Engineer team workflow (step added before implementation starts)

### 6. Token Budget Protocol v2

Modernize ADR-0007's budgets with loop-engineering integration:

#### 6.1 Per-Phase Budgets (Carried Forward from ADR-0007)

| Phase | Max Tokens | Notes |
|-------|-----------|-------|
| Context load | 8k | Design doc + ADRs + search_memories summary |
| Code generation | 12k | Spec + constraints + implementation |
| Code review | 8k | Diff + standards + ADR compliance |
| Test generation | 8k | Spec + code + edge cases |
| Documentation | 4k | Code + decisions |
| Second opinion | 6k | Cross-model validation |

**Budget enforcement:** Per-phase budgets are **guidelines** — they trigger warnings at 80% and alerts at 100%, but only the 200% threshold is a hard stop that refuses delegation. The 8k context load budget is intentionally conservative; exceeding it does not block work. Budgets serve as awareness tools, not enforcement gates. Actual token consumption is tracked via `token_usage.py` to inform future budget calibration.

#### 6.2 Per-Automation-Run Caps (NEW)

Each autonomous loop run has a hard token cap, enforced by `token_usage.py` being checked after each `opencode run` invocation. If a run exceeds its cap, the loop is paused (writes `.loop_paused` marker) and an alert is stored via `add_memory`.

| Loop | Max Tokens/Run | Rationale |
|------|---------------|-----------|
| Daily Triage | 3k | Lightweight: read-only status checks, report generation |
| PR Babysitter | 2k | Minimal: check PR status, generate summary |
| Drift Detection | 4k | Moderate: file comparison, state validation |
| Default (manual) | 8k | Standard delegation budget |

**Fallback logging:** As a backup, loop reports are also appended to `loop-run-log.md` as plain text via the cron wrapper script (`scripts/loop-run.sh`, see §4.1). This ensures visibility even if the opencode-mem MCP connection is temporarily unavailable or `add_memory` calls silently fail.

#### 6.3 Kill Switch: loop-pause-all

A `.loop_pause_all` marker file acts as a global kill switch. When present:
- All cron jobs skip execution (check at start)
- Director warns on session start that automation is paused
- Manual operations continue unaffected

Created by:
- Token cap exceeded on any loop → auto-create
- User manually: `touch .loop_pause_all`

Removed by:
- **Auto-expiry:** `.loop_pause_all` auto-expires after 24 hours. A warning is logged via `add_memory` on expiry. The user can extend the pause by `touch .loop_pause_all` again (resets the 24-hour timer).
- **Force-resume:** User can `rm .loop_pause_all` at any time to resume immediately.
- After investigation + fix, Scribes removes the marker.

#### 6.4 Cost Tracking (NEW)

`token_usage.py` queries OpenCode's SQLite database for aggregated token counts:

```
# Output format (JSON)
{
  "period": "2026-07-21",
  "teams": {
    "architects": 4200,
    "engineers": 8900,
    "testers": 1200,
    "reviewers": 3400,
    "scribes": 800,
    "fls": 0,
    "director": 2100
  },
  "total": 20600,
  "loop_runs": {
    "daily_triage": { "runs": 5, "tokens": 12000, "avg_per_run": 2400 }
  }
}
```

Stored via `add_memory(content="...", scope="project", tags=["loop_cost"])` for historical tracking.

#### 6.5 Director's Warning Protocol (Updated)

Before each delegation, Director:
1. Runs `scripts/token_usage.py` (if available)
2. Checks against per-phase budget
3. **80% of budget** → warns user: "Approaching token budget for `<phase>`: `<current>`/`<max>`"
4. **100% of budget** → alerts user: "Token budget exceeded. Consider context compression or smaller scope."
5. **200% of budget** → hard stop: refuses delegation, suggests session reset

### 7. State Management: Dual-State Files

Maintain two state files with different purposes:

| File | Purpose | Format | Readers |
|------|---------|--------|---------|
| `.kodehold-state` | Machine-readable lifecycle state | `KEY=VALUE` lines | gate.py, scripts, cron jobs |
| `STATE.md` | Human-readable loop state | Markdown with sections | Director, human operators |

**STATE.md template:**

```markdown
# KodeHold Loop State

**Last updated:** 2026-07-21T08:00:00Z
**Loop Ready Score:** TBD (awaiting Phase 1.1)

## Active Loops

| Loop | Schedule | Status | Last Run | Tokens Used |
|------|----------|--------|----------|-------------|
| Daily Triage | Weekdays 08:00 | Pending | — | — |
| PR Babysitter | Every 4h, 08-16 | Pending | — | — |
| Drift Detection | Sunday 10:00 | Pending | — | — |

## Health

| Check | Status |
|-------|--------|
| Tests passing | yes |
| Gate markers clean | yes |
| No drift detected | yes |
| Token budget OK | yes |

## Recent Loop Reports

<!-- Scribes appends loop reports here as they are generated -->
```

Scribes updates `STATE.md` after each loop iteration (Phase 2+) and after lifecycle transitions. `STATE.md` content is also stored via `add_memory(tags=["loop_state"])` for searchability.

### 8. Scoring: Loop Ready Score

Run `loop-audit` on KodeHold to establish baseline. The tool assesses:

1. **Loop Definition Clarity** — Are loops well-specified? (Daily Triage, PR Babysitter — to be defined in Phase 2)
2. **Memory Architecture** — Persistent state across runs? (opencode-mem via MCP)
3. **Error Handling** — Graceful failure? (Kill switch, caps, FLS escalation)
4. **Observability** — Can you see what's happening? (STATE.md, loop reports, token tracking)
5. **Safety** — Can it damage itself? (Markers, gates, report-only L1 mode)

**Initial estimated score:** 60-70 (strong on Memory, Skills, Sub-agents; weak on Scheduling, Loop Definition, Observability).

**Target:** ≥80 before Phase 2 automation begins.

### 9. Deprecate ADR-0007

ADR-0007 (Token Optimization Strategy) is superseded by this ADR:

- **English-only policy** → absorbed into ADR-0049 (The Ladder) and general KodeHold conventions
- **Tiered context loading** → superseded by Graphify (ADR-0054) + opencode-mem (ADR-0051) retrieval
- **Minimal prompt templates** → replaced by The Ladder's YAGNI principle (ADR-0049)
- **File chunking >150 lines** → superseded by Graphify's structural queries
- **Context deduplication** → handled by opencode-mem auto-capture
- **Per-phase token budgets** → modernized and extended in this ADR (§6)
- **Token tracking** → replaced by `token_usage.py` + loop-cost integration

ADR-0007 status changes from **Accepted** to **Superseded** with reference to this ADR.

### 10. Future Work (Phase 4+ — Out of Scope)

| Topic | Description | When |
|-------|-------------|------|
| Fleet Management | Multi-project orchestration (loop-engineering → fleet-engineering) | Post-Phase 3 |
| Goal Mode (L3 unattended) | "Run until condition met" with full autonomy | Post-Phase 3, requires extensive safety testing |
| L2 Assisted Fixes | PR Babysitter auto-fixes merge conflicts, stale branch cleanup | Post-Phase 2, after L1 proven stable |
| Outerloop Integration | harness-foundry → outerloop for multi-loop coordination | Beyond fleet management |

## Consequences

### Positive

- **Operational maturity:** KodeHold graduates from a solely human-triggered system to one with autonomous maintenance loops. Design work (Architects) and implementation (Engineers) remain human-triggered; only maintenance/observation is automated.
- **Token cost visibility:** `token_usage.py` + loop-cost tracking provides concrete per-loop and per-team token consumption data, replacing the aspirational budgets of ADR-0007 with measurable reality.
- **Safety-first automation:** All automation starts at L1 (report-only). L2/L3 requires proven reliability. Kill switch (`loop_pause_all`) provides emergency stop with 24-hour auto-recovery. Per-run caps prevent runaway loops. Cron wrapper script creates `.loop_error` markers for FLS triage on failure.
- **Declarative gates:** `config/gate.yaml` makes gate definitions auditable, diffable, and loop-gate compatible — replacing 771 lines of Python with a structured YAML file + thin wrapper.
- **Drift detection:** loop-sync prevents the "design doc says X, code does Y" problem that arises when loops run against stale context.
- **Aligned with ecosystem:** Adopting loop-engineering patterns makes KodeHold compatible with the broader agent engineering toolchain (loop-audit, loop-cost, loop-gate).

### Negative

- **Integration complexity:** Three phases spanning weeks/months. Phase dependencies must be respected (Phase 2 cannot start without Phase 1's baseline score and token tracking).
- **Token overhead of loops:** Daily Triage + PR Babysitter + Drift Detection add ~9k tokens/day (3k + 2k + 4k). Even at conservative rates (~$3/M tokens), this adds marginal cost. But for local Ollama models, context window pressure is the real concern.
- **Cron fragility:** Cron jobs have no intrinsic error handling. A failed `opencode run` invocation could silently fail. Mitigation: The `scripts/loop-run.sh` wrapper script logs exit codes and creates `.loop_error` markers on failure (preventive, not reactive). Additional mitigations: loop-pause-all auto-created on token cap breach; STATE.md tracks last run times; FLS triages `.loop_error` markers.
- **OpenCode SQLite dependency:** `token_usage.py` reads OpenCode's internal database schema, which is not a public API. Schema changes could break the script. Mitigation: schema version check + graceful degradation.
- **Design document impact:** This ADR's adoption requires updates to `docs/design/README.md`: ADR Index (add ADR-0058), Token Optimization section (mark as superseded by ADR-0058), Architecture Overview (add loop-engineering scheduling layer), and Implementation Plan (add Phase 1-3 roadmap milestones).

### Risks

- **Loop runaway:** An unsupervised loop could consume tokens indefinitely if a bug in `opencode run` causes it to never exit. **Mitigation:** Per-run token caps (§6.2) + kill switch with 24-hour auto-recovery (§6.3). Cron jobs have a secondary timeout via `timeout` command in the wrapper script.
- **State drift during automation:** A loop could act on stale state if `.kodehold-state` is not synced. **Mitigation:** loop-sync drift detection (Phase 2.3) catches this before loops make decisions.
- **Worktree isolation complexity:** git worktrees introduce new failure modes (locked index files, disk space exhaustion, merge conflicts). **Mitigation:** Separate ADR for worktree design. Limited worktree count (max 3 concurrent). Cleanup cron job.
- **gate.yaml/gate.py divergence:** During the dual-validation period, if gate.yaml and gate.py disagree, which one is authoritative? **Mitigation:** gate.py is authoritative until Phase 3.3. gate.yaml is validated for parity but not enforced. Integration tests assert parity.
- **Concurrent write protection:** `.kodehold-state` and `STATE.md` are both updated during loop runs — without locking, concurrent writes could corrupt state. **Mitigation:** Cron jobs are staggered (no overlapping intervals). Scribes updates are serialized through Director delegation. If concurrent writes become a problem, a `.state_lock` file-based mutex can be added.

## Effort

| Phase | Milestone | Estimate | Dependencies |
|-------|-----------|----------|-------------|
| P1.1 | loop-audit baseline | 1 session | Validate `loop-audit` CLI availability first |
| P1.2 | gate.yaml | 2 sessions | Analyze all 5 gate.py transitions |
| P1.3 | token_usage.py | 1 session | OpenCode SQLite schema analysis |
| P1.4 | ADR-0007 deprecation | Done (this ADR) | — |
| P1.5 | STATE.md | 1 session | Scribes workflow update |
| P2.1 | Daily Triage Loop | 2 sessions | Phase 1 complete, cron + wrapper setup |
| P2.2 | PR Babysitter Loop | 1 session | P2.1 patterns established |
| P2.3 | loop-sync | 2 sessions | Design doc/index analysis |
| P2.4 | Token Budget Monitoring | 1 session | P1.3 complete |
| P3.1 | Worktree ADR + implementation | 3+ sessions | Separate ADR, extensive testing |
| P3.2 | Goal Mode Skill | 2 sessions | Prospective memory (ADR-0021) |
| P3.3 | Gate Migration | 1 session | gate.yaml validated over months |

**Phase 1 total:** ~5 sessions (1-2 weeks).
**Phase 2 total:** ~6 sessions (2-3 weeks, plus 7-day burn-in).
**Phase 3 total:** ~6+ sessions (3+ weeks, worktree ADR is largest unknown).

## Documentation

| Field | Value |
|-------|-------|
| **Tool** | Loop Engineering (cobusgreyling/loop-engineering) |
| **Official docs** | https://github.com/cobusgreyling/loop-engineering |
| **Version documented** | v1.6.0 (2026-07-20) |
| **Key sections read** | `docs/primitives.md` (Five Building Blocks + Memory), `docs/concepts.md` (Intent Debt, Comprehension Debt, Cognitive Surrender), `docs/architecture-diagrams.md` (loop cycle, run lifecycle, autonomy levels L1-L3, stack mapping), `patterns/README.md` (7 patterns), `examples/opencode/daily-triage.md`, `tools/` (loop-audit, loop-cost, loop-init, loop-sync, loop-worktree, loop-gate, loop-context, loop-mcp-server), `docs/loop-design-checklist.md` (10-section readiness rubric) |
| **Key API concepts** | **Five primitives:** (1) Automations/Scheduling — cadence, fire-immediately, durable; (2) Worktrees — git worktree isolation per attempt, lifecycle create→commit→merge→cleanup; (3) Skills — SKILL.md + scripts, unit of reuse, intent debt reduction; (4) MCP Connectors — read/write external systems (GitHub, Jira, Slack); (5) Sub-agents — maker/checker split, implementer never grades own work. **+Memory/State:** STATE.md durable spine, `.loop_pause_all` kill switch, `loop-budget.md` caps. **Autonomy levels:** L1 (report-only), L2 (assisted fixes with verifier), L3 (unattended). **Toolchain:** `loop-audit` scores 0-100 across clarity, memory, error handling, observability, safety; `loop-cost` estimates per-run spend; `loop-sync` detects state/doc drift; `loop-gate` enforces denylist + allowlist from gate.yaml |
| **Configuration prerequisites** | opencode CLI (for `opencode run`), crontab access, loop-engineering CLI tools (npm: `npx @cobusgreyling/loop-audit`, `npx @cobusgreyling/loop-cost`, `npx @cobusgreyling/loop-init`), git worktree support (git 2.5+) |
| **Gotchas** | (1) `loop-audit` scoring categories may not perfectly align with KodeHold's team metaphor — treat score as directional, not absolute. (2) `opencode run --prompt` CLI syntax should be verified before crontab deployment; fallback to `--file` if `--prompt` is not supported in the current opencode version. (3) OpenCode SQLite schema for `token_usage.py` is not a public API — schema version check required. (4) Cron fragility: cron has no intrinsic error handling — the `scripts/loop-run.sh` wrapper script logs exit codes and creates `.loop_error` markers to prevent silent failures. (5) `add_memory` MCP calls can silently fail if opencode-mem connection drops — `loop-run-log.md` provides plain-text fallback for loop reports. (6) Per-phase token budgets (8k context load) may be aspirational rather than hard caps given design doc + ADRs easily exceed this — budgets serve as guidelines with warnings at 80% and alerts at 100%; only the 200% threshold is a hard stop. |

## References

- Loop Engineering: https://github.com/cobusgreyling/loop-engineering
- Loop Engineering Ecosystem: memory-engineering → loop-engineering → harness-foundry → outerloop → fleet-engineering
- ADR-0007: Token Optimization Strategy (superseded by this ADR)
- ADR-0021: Prospective Memory (Task Queue & Scheduler) — used by Goal Mode
- ADR-0048: Mandatory Tool Documentation Review Before Implementation — requires `## Documentation` section in ADRs that select external tools
- ADR-0049: The Ladder — YAGNI, deletion over addition
- ADR-0051: opencode-mem Persistent Memory Backend
- ADR-0054: Graphify Knowledge Graph for Code Retrieval
- ADR-0057: Migrate File-Based Memory to opencode-mem

## Review Notes

- **2026-07-21 (v1):** Initial proposal. Integrates loop-engineering as KodeHold's operational framework. Defines three-phase roadmap with clear gates. Modernizes token budget protocol from ADR-0007. Adds per-automation-run caps, kill switch, STATE.md, and declarative gate.yaml. ADR-0007 status updated to Superseded.
- **2026-07-21 (v2):** Revised per Reviewers (BLOCKING: missing `## Documentation` section per ADR-0048 §3) and Second Opinion (4 must-fix, 3 should-fix items). Changes: (1) Added `## Documentation` section with loop-engineering reference, API concepts, prerequisites, and 6 gotchas. (2) Clarified per-phase budgets as guidelines (warnings at 80%, alerts at 100%, hard stop at 200%). (3) Added 24-hour auto-expiry to `.loop_pause_all` kill switch with `touch`-to-extend. (4) Added `scripts/loop-run.sh` cron wrapper script with exit code logging and `.loop_error` marker creation. (5) Added `loop-run-log.md` as plain-text fallback for `add_memory` failures. (6) Tightened Phase 2 completion gate to require meaningful findings or explicit "no issues found" per loop per day over 7 consecutive weekdays. (7) Noted `opencode run --prompt` CLI syntax must be verified before deployment. (8) Added "Impact on Design Document" to Consequences. (9) Noted concurrent write protection for dual-state files as a risk with staggered-cron mitigation.
- **2026-07-21 (Accepted):** ADR accepted after Reviewers PASS (v2) and Second Opinion approval.
