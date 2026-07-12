---
type: decision
date: 2026-06-28
status: reviewed
topic: test coverage review
---

# Test Coverage Review — 2026-06-28

## Context

After completing ADR-0050 migration, ponytail audit fixes, CI workflow updates, and fixing 5 pre-existing test failures, the Director performed a comprehensive test coverage review against the design doc, ADRs, AGENTS.md, and agent files.

## Current State

**13 tests, 0 failures, 46 pytest cases all pass**

| Section | Tests | What's Covered |
|---------|-------|----------------|
| Smoke | 4 files | File structure, frontmatter validity, ADR format, design doc sections |
| Init | 4 files (3 sh + 1 py) | Config validity, `.opencode/memory/`, ADR index, YAML config (46 pytest cases) |
| Integration | 5 files | Agent loadability, lifecycle states, design-ADR alignment, FLS workflow, gate marker enforcement |

## Coverage Gaps (Prioritized)

### P0 — Must Fix

| # | Gap | Design Doc § | What's Missing |
|---|-----|-------------|----------------|
| 1 | `gate.sh` transition coverage | §6.2 | Only `INIT_TO_ACTIVE` tested. `ACTIVE_TO_REVIEW`, `REVIEW_TO_CLOSED`, `REOPEN_TO_ACTIVE` unknown |
| 2 | `ship.sh` untested | Shipping Gate | 8-step shipping gate (Phase 2) completely untested |
| 3 | Git commit protection | §6.4 | No test for untracked file detection before session end |

### P1 — Should Fix

| # | Gap | Design Doc § | What's Missing |
|---|-----|-------------|----------------|
| 4 | `workspace.sh` untested | §7.6, ADR-0012 | `init`, `adopt`, `list`, `state`, `deploy-ready` commands |
| 5 | `validate-config.sh` / `sync-agent-config.sh` indirect only | ADR-0037 | Only tested via pytest subprocess; no standalone shell test |
| 6 | `token-usage.sh` / `token-report.py` untested | §9 | Token tracking and reporting scripts |
| 7 | Project structure incomplete | §10 | Doesn't verify `config/agents.yaml`, `.opencode/skills/*`, `scripts/lib/` |
| 8 | Agent content beyond FLS | §3 | Only FLS has workflow content tests; director, architects, engineers, reviewers, testers, scribes are structure-only |

### P2 — Next Sprint

| # | Gap | Design Doc § | What's Missing |
|---|-----|-------------|----------------|
| 9 | Second opinion agent | §8.3 | Cross-model validation agent config not validated |
| 10 | Light mode | §8.2 | `KODEHOLD_LIGHT=1` behavior untested |
| 11 | Prospective memory | §7.7 | Storage format, session-start integration, max 35 tasks |
| 12 | Design doc file layout stale | §10 | Still references `.agentmemory/` — removed in ADR-0050 |

### P3 — Nice to Have

| # | Gap | Design Doc § | What's Missing |
|---|-----|-------------|----------------|
| 13 | ADR numbering duplicates | ADR index | Two ADR-0019 files; no test catches number conflicts |
| 14 | Skills file existence | §7.4 | `investigate`, `opencode-rag-knowledge-flow`, `state-awareness` on disk? |
| 15 | Edge cases | Various | Missing `.kodehold-state`, malformed config, gate.sh without markers |
| 16 | CI workflow self-test | — | CI YAML references all sections; no test validates this |
| 17 | Adopted project symlinks | §7.6 | Symlink creation, resolution, test discovery |
| 18 | Design doc freshness | §10 | File layout vs actual `ls` — drift detection |

## Recommended Action Plan

1. **Phase 1 (this session):** Add P0 tests — gate.sh ACTIVE_TO_REVIEW, REVIEW_TO_CLOSED, REOPEN_TO_ACTIVE
2. **Phase 2:** Add ship.sh tests, git commit protection test
3. **Phase 3:** Add workspace.sh and script-specific tests
4. **Phase 4:** Update design doc file layout, add content tests for agents
5. **Phase 5:** Edge cases, ADR numbering, skills validation
