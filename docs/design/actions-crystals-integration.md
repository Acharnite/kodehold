# Design Document: Agentmemory Actions + Crystals Integration for KodeHold Director

**Version:** 0.1  
**Status:** Draft — saved for later implementation  
**Design Authority:** Architects  
**Last Updated:** 2026-05-31  

> **Note:** This document was created on 2026-05-31 as a forward-looking design proposal.
> It has been saved for future implementation. See the Executive Summary below for a quick overview.

---

## Executive Summary

### What
Integrate agentmemory's **Orchestration Layer** (Actions, Crystals, Leases, Frontiers, Routines, Signals, Sentinels, Sketches, Checkpoints) into the KodeHold Director's delegation and lifecycle management.

### Why
Currently, the Director manages multi-team workflows through:
- Manual `todowrite` lists for task sequencing
- Flat `.kodehold-state` file for lifecycle tracking
- Ad-hoc ICM checkpoint stores at intervals
- No dependency graph enforcement, lease mechanism, or automated lesson extraction

### Key Benefits
| Capability | Today | With Actions + Crystals |
|------------|-------|------------------------|
| Task sequencing | Manual `todowrite` | `memory_frontier` shows unblocked actions |
| Dependency tracking | Director's memory | `requires` chains enforced by agentmemory |
| Delegation safety | None | `memory_lease` prevents double-delegation |
| Lessons learned | Manual via Scribes | Auto-extracted by `memory_crystallize` |
| Checkpoints | Manual ICM stores | Auto-generated crystal digests |
| Common flows | Ad-hoc per task | Routine templates (ADR, implement, bugfix, ship) |

### Migration Plan (6 Phases)
1. **Awareness** — Fire-and-forget action creation, no behavior change
2. **Frontier Awareness** — Read frontier but follow todowrite
3. **Frontier-Driven** — Frontier drives delegation (opt-in)
4. **Routine Templates** — ADR/implement/bugfix/ship flows automated
5. **Crystals + Signals** — Auto-crystallize, inter-agent signals
6. **Backward Compatibility** — Verify fallback, light mode, existing tools

---

## Quick Reference

### Action Types
| Type | Team | Priority | Used For |
|------|------|----------|----------|
| `design` | architects | 8 | ADRs, design docs |
| `review` | reviewers | 7 | Design/code review |
| `implement` | engineers | 8 | Feature implementation |
| `test` | testers | 6 | Test writing + execution |
| `gate-validation` | reviewers | 9 | Gate.sh --validate-only |
| `gate-execution` | director | 9 | Gate.sh --transition |
| `document` | scribes | 5 | Documentation |
| `triage` | fls | 7 | Bug investigation |
| `ship` | director | 9 | Shipping gate |
| `second-opinion` | second-opinion | 7 | Cross-model validation |

### Standard Flow Templates
See Sections 8.1 for full template definitions:
- `kodehold-adr-flow` — 6 steps
- `kodehold-implement-flow` — 6 steps  
- `kodehold-bugfix-flow` — 5 steps (branching)
- `kodehold-ship-gate` — 7 steps

### Key MCP Tools
| Tool | Purpose | 
|------|---------|
| `memory_action_create` | Create work item with deps |
| `memory_action_update` | Update status (done/blocked) |
| `memory_frontier` | Get next unblocked action |
| `memory_lease` | Acquire/release exclusive lock |
| `memory_crystallize` | Compress completed chain into digest |
| `memory_routine_run` | Instantiate standard flow |
| `memory_signal_send/read` | Inter-agent messaging |
| `memory_sentinel_create/trigger` | Event-driven unblocking |
| `memory_sketch_create/promote` | Ephemeral investigation |

---

## Full Design Document

The complete design document covers 16 sections:
1. Purpose & Scope
2. Requirements (functional + non-functional)
3. Architecture Overview (two-layer architecture, graceful degradation)
4. Action Schema (types, priorities, metadata)
5. Dependency Model (standard flow DAGs, parallel actions, gate semantics)
6. Frontier Flow (director loop, integration points, lease management)
7. Crystal Strategy (triggers, scope, integration with existing checkpoints)
8. Routine Templates (4 predefined: ADR, implement, bugfix, shipping)
9. Signal/Sentinel/Sketch/Checkpoint Integration
10. Integration Points in Director (session lifecycle modifications)
11. Migration Path (6 phases)
12. Risks and Mitigations (11 risks mapped)
13. Action Model Phasing (per-lifecycle-state)
14. ADR Index (future ADRs)
15. Open Questions (6 items)
16. Changelog

See the full text in the sections below for implementation details.
