# ADR-0031: Actions + Crystals for Director Delegation

## Status

Proposed

**Phase:** Phase 3 (Frontier-Driven Delegation) — replaces the Director's manual `todowrite` sequence protocol with agentmemory's action orchestration layer.

## Context

### The Problem

The KodeHold Director currently manages multi-team workflows through three ad-hoc mechanisms:

1. **Manual `todowrite` lists** — The Director creates sequential todo markers (e.g., `todowrite "1. design (pending)"`, `todowrite "2. review (pending)"`). These are unstructured text strings with no dependency enforcement, priority ordering, or status tracking. The Director must maintain the entire sequence in working memory.

2. **Flat `.kodehold-state` file** — The project lifecycle state (`INIT`, `ACTIVE`, `REVIEW`, `CLOSED`, `REOPEN`) is tracked in a single file. There is no dependency graph, no parallel execution tracking, and no automated state validation.

3. **Ad-hoc ICM checkpoint stores** — The Director stores periodic checkpoints in ICM. These are unstructured memory writes with no relationship to the task graph.

**Consequences of the current approach:**

- **No dependency graph enforcement.** The Director must manually ensure actions complete in order. A downstream delegation could accidentally start before upstream work finishes.
- **No parallel execution awareness.** The Director cannot easily determine which actions can run in parallel (e.g., architects design + scribes research).
- **No lease mechanism.** If two sessions run concurrently, both could delegate the same task.
- **No automated lesson extraction.** Completed work must be manually summarized and stored. There is no automatic compression of completed work chains.
- **No frontier.** The Director must manually scan all pending items to determine what to do next. There is no "what's the next most important unblocked action" query.

### Key Forces

1. **Backward compatibility.** Phase 1 (Awareness) dual-writes actions alongside existing todowrite. The Director can fall back to todowrite at any time.
2. **Opt-in adoption.** The Director chooses when to start reading `memory_frontier` instead of maintaining todo lists.
3. **Gradual migration.** Phase 1 adds action creation (fire-and-forget). Phase 3 makes frontier the primary delegation driver. Phase 4 adds routine templates on top of actions.
4. **Lease safety.** No two agents should ever work on the same action simultaneously.
5. **Crystal value.** Completed action chains should be automatically compressed into useful digests.
6. **Graceful degradation.** If agentmemory is unavailable, the Director must fall back to todowrite.

### Prior Art

- **ADR-0029** (ICM → Agentmemory Migration Strategy) — established the 6-phase migration; this ADR implements Phase 3
- **Actions+Crystals design doc** (`docs/design/actions-crystals-integration.md`) — defines action types, dependency model, frontier flow, crystal strategy (Sections 4-7)
- **ADR-0004** (ICM and RTK Integration) — to be deprecated by this ADR; this ADR replaces ICM-based delegation with action-based delegation
- **ADR-0009** (ICM MCP Integration) — to be deprecated by this ADR; agentmemory's MCP tools replace ICM's
- **ADR-0021** (Prospective Memory) — to be superseded by this ADR; task queues migrated to actions
- **ADR-0015** (Director Delegation Enforcement) — established tool permission enforcement; this ADR extends that with lease-based enforcement

## Decision

### Adopt Agentmemory Actions + Crystals as the Primary Delegation Workflow

#### Action Types

Define 10 action types covering all KodeHold work:

| Type | Priority | Default Team | Used For |
|------|----------|-------------|----------|
| `design` | 8 | architects | ADRs, design docs, architecture decisions |
| `review` | 7 | reviewers | Design/code review |
| `implement` | 8 | engineers | Feature implementation |
| `test` | 6 | testers | Test writing + execution |
| `gate-validation` | 9 | reviewers | Gate.sh --validate-only |
| `gate-execution` | 9 | director | Gate.sh --transition |
| `document` | 5 | scribes | Documentation updates |
| `triage` | 7 | fls | Bug investigation |
| `ship` | 9 | director | Shipping gate |
| `second-opinion` | 7 | second-opinion | Cross-model validation |

Priorities: 6-9 range. Higher = more urgent. Gate and ship actions (9) run first. Documentation (5) runs last.

#### Dependency Model

Actions use `requires` to define a DAG of dependencies:

```
memory_action_create(type="design", requires=[])           # No dependencies — can start immediately
memory_action_create(type="review", requires=["design-001"])  # Blocks until design-001 is done
memory_action_create(type="implement", requires=["review-001"])  # Blocks until review approves
```

Key rules:
- Actions with empty `requires` are **unblocked** and returned by `memory_frontier`
- Actions with unsatisfied `requires` are **blocked** and hidden from `memory_frontier`
- Multiple actions can require the same action (fan-out parallelism)
- An action can require multiple actions (fan-in synchronization)

#### Frontier Flow (Director Delegation Loop)

Replace the current `todowrite` sequence with the action frontier:

```
# Current (todowrite):
1. Director maps task sequence in working memory
2. Director creates todowrite with pending/completed markers
3. Director delegates to team
4. Director updates todowrite status
5. Director stores checkpoint in ICM

# New (actions + frontier):
1. Director creates actions with dependency chain
   memory_action_create(type="design", requires=[], priority=8)
   memory_action_create(type="review", requires=["design-001"], priority=7)
   
2. Director reads frontier for next unblocked action
   memory_frontier → returns action with highest priority + no blockers
   
3. Director acquires lease on action
   memory_lease(action_id, agentId="director") → exclusive lock
   
4. Director delegates to team via Task tool
   
5. Team completes work (uses agentmemory for context + storage)
   
6. Director updates action with result
   memory_action_update(action_id, status="done", result="summary")
   
7. Director crystallizes completed chain (Phase 5)
   memory_crystallize(chain_ids) → auto-digest
   
8. Director releases lease
   memory_lease(action_id, agentId="director", operation="release")
```

#### Lease Management

Leases prevent double-delegation:
- `memory_lease(action_id, agentId)` acquires an exclusive lock
- Lease has TTL (default 10 minutes, max 1 hour)
- If lease expires, another agent can claim the action
- On completion: `memory_lease(action_id, ..., operation="release")`
- On failure: lease expiry re-exposes the action

#### Crystal Strategy

Crystals compress completed action chains into compact digests:

| Trigger | Scope | Timing |
|---------|-------|--------|
| Per-flow completion | All actions in a flow template | After last action marked `done` |
| Per-gate | Actions in a lifecycle transition | After gate.sh passes |
| Explicit | Single action or chain | When `crystallize: true` set on action |

Each crystal contains:
- Narrative summary of what was done
- Key outcomes and decisions
- Files affected
- Lessons learned (auto-extracted)
- Action chain metadata (types, teams, duration)

### What This Changes

- **Director's delegation loop:** From `todowrite` → `memory_frontier` + `memory_lease`
- **Director agent file:** Replace "Todo Sequence Protocol" section with "Action Frontier Protocol"
- **Scribes post-task:** Add `memory_action_update` and `memory_crystallize` steps
- **ADR-0004:** Mark as Deprecated (replaced by action-based delegation)
- **ADR-0009:** Mark as Deprecated (ICM MCP not needed with agentmemory actions)
- **ADR-0021:** Mark as Superseded (prospective memory tasks become actions)
- **ADR-0019:** Mark as Superseded (session compression via crystals)
- **Benchmark scripts:** Rewrite for agentmemory or deprecate
- **Consolidate scripts:** Deprecate (agentmemory auto-consolidates; crystals provide human-readable digests)

### Migration Path Within This ADR

| Sub-Phase | What Happens | Behavior |
|-----------|-------------|----------|
| 3.0 | Actions created alongside todowrite (Phase 1 already did this) | No behavioral change |
| 3.1 | Director reads `memory_frontier` for awareness but still follows todowrite | Monitoring only |
| 3.2 | Director uses frontier as primary driver, falls back to todowrite if frontier empty | Opt-in |
| 3.3 | Todowrite removed; only `memory_frontier` used | Full migration |

## Consequences

### Positive

1. **Dependency graph enforcement.** Agentmemory's `requires` chains ensure actions execute in correct order. No manual sequencing.
2. **Frontier-driven prioritization.** `memory_frontier` returns the single highest-priority unblocked action. Director always works on the most important task.
3. **Lease-based delegation safety.** No double-delegation. Leases expire and re-expose stuck actions.
4. **Automated lesson extraction.** `memory_crystallize` generates compact digests of completed work. No manual summarization.
5. **Parallel execution awareness.** Multiple unblocked actions with no dependency on each other can run in parallel.
6. **Graceful degradation.** If agentmemory is unavailable, Director falls back to todowrite (manual mode).
7. **Reduced Director cognitive load.** No need to maintain task sequences in working memory. The frontier handles ordering.

### Negative

1. **Agentmemory coupling increases.** The Director's core delegation loop now depends on agentmemory being available. Without it, KodeHold operates in degraded manual mode.
2. **Learning curve.** Director must learn: `memory_action_create`, `memory_action_update`, `memory_frontier`, `memory_lease`, `memory_crystallize`. These are new tools not previously used.
3. **Performance overhead.** Each delegation step requires 3-4 agentmemory API calls (create/read frontier/lease/update) instead of a single todowrite. Latency accumulates.
4. **Lease expiry edge cases.** If a lease expires while a team is still working on the action, another agent could claim it. Mitigation: generous TTL (30 min default).
5. **Crystal storage.** Each crystal is a memory entry. Over time, crystals accumulate. Mitigation: crystals are compact; periodic consolidation keeps them manageable.

### Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Frontier returns unexpected results** — blocks when it shouldn't or unblocks when it shouldn't | Medium | Critical | Phase 3.0-3.1 dual-writes actions + todowrite. Director always has manual fallback. |
| 2 | **Lease expires during long-running task** — agent reclaims action mid-work | Low | High | Set lease TTL per action type (implement: 60min, review: 30min). Director can renew lease. |
| 3 | **Action chain corruption** — `requires` references invalid action ID | Low | Medium | Use action types + sequence IDs for requires strings. Validate before create. |
| 4 | **Crystalization fails** — `memory_crystallize` returns unexpected or empty digest | Low | Low | Crystals are additive. If crystalization fails, original actions remain accessible. |
| 5 | **Director too reliant on frontier** — loses situational awareness of full project state | Medium | Medium | Director runs `memory_action_list` or equivalent periodically for full-state awareness. |

### Follow-up Items

- [ ] Update `.opencode/agents/director.md` — replace "Todo Sequence Protocol" with "Action Frontier Protocol"
- [ ] Update `.opencode/agents/scribes.md` — add action management and crystal consumption
- [ ] Mark ADR-0004 as Deprecated
- [ ] Mark ADR-0009 as Deprecated
- [ ] Mark ADR-0021 as Superseded
- [ ] Mark ADR-0019 as Superseded
- [ ] Deprecate `scripts/benchmark.sh` or rewrite for agentmemory
- [ ] Deprecate `scripts/consolidate-all.sh`
- [ ] Update design doc Section 5 to reference Actions-based workflow

### How to Revert

1. **Soft revert:** Stop reading `memory_frontier`. Fall back to todowrite-based delegation (todowrite was never removed during dual-write phase).
2. **Hard revert:** `git restore` director.md and scribes.md to pre-action state. Existing actions in agentmemory are orphaned but cause no harm.
3. **ADR revert:** Reactivate ADR-0004, ADR-0009, ADR-0021. Deprecate this ADR.

## ADR References

- **ADR-0004** (ICM and RTK Integration) — **Deprecated** by this ADR. ICM-based delegation replaced by agentmemory actions.
- **ADR-0009** (ICM MCP Integration) — **Deprecated** by this ADR. ICM MCP tools replaced by agentmemory MCP tools.
- **ADR-0019** (Session Context Compression) — **Superseded** by this ADR. Crystals replace ICM-based compression.
- **ADR-0021** (Prospective Memory) — **Superseded** by this ADR. Task queues become actions.
- **ADR-0029** (ICM → Agentmemory Migration Strategy) — Phase 3 of the migration plan; this ADR implements that phase.
- **ADR-0015** (Director Delegation Enforcement) — extended by this ADR; leases add enforcement beyond tool permissions.
- **ADR-0030** (Agentmemory Knowledge Flow) — prerequisite; agentmemory must be the primary memory system before actions can work.
- **ADR-0032** (Routine Templates) — builds on this ADR's action model; routines are parameterized action DAGs.
- **ADR-0033** (Inter-Agent Signals + Sentinels) — builds on this ADR; signals activate between actions.
- **Actions+Crystals design doc** (`docs/design/actions-crystals-integration.md`) — Sections 4-7 define action schema, dependency model, frontier flow, and crystal strategy.

### Source Files Referenced

- `.opencode/agents/director.md` — contains "Todo Sequence Protocol" section to be replaced
- `.opencode/agents/scribes.md` — contains post-task workflows to be extended with action management
- `docs/design/actions-crystals-integration.md` — action schema, types, priorities, dependency model (Sections 4-7)
- `docs/adr/ADR-0004-icm-rtk-integration.md` — to be deprecated
- `docs/adr/ADR-0009-icm-mcp-integration.md` — to be deprecated
- `docs/adr/ADR-0019-session-context-compression.md` — to be superseded
- `docs/adr/ADR-0021-prospective-memory.md` — to be superseded
- `scripts/benchmark.sh`, `scripts/consolidate-all.sh` — to be deprecated or rewritten
