# ADR-0032: Routine Templates for Standard Flows

## Status

Proposed

**Phase:** Phase 4 (Routine Templates) — builds on Phase 3's action model to define standard flow templates that can be instantiated with a single `memory_routine_run` call.

## Context

### The Problem

KodeHold executes several multi-step workflows repeatedly. Each time, the Director must manually create the full action dependency chain:

**Example — ADR creation flow:**
1. `memory_action_create(type="design", requires=[], priority=8)` — architects research
2. `memory_action_create(type="design", requires=["research-done"], priority=8)` — architects write ADR
3. `memory_action_create(type="document", requires=["adr-written"], priority=5)` — scribes update design doc
4. `memory_action_create(type="review", requires=["adr-written"], priority=7)` — reviewers review
5. `memory_action_create(type="second-opinion", requires=["adr-written"], priority=7)` — cross-validate
6. `memory_action_create(type="document", requires=["review-done", "second-opinion-done"], priority=5)` — scribes finalize

This is 6 `memory_action_create` calls, 6 `requires` chain constructions, and 6 manual priority assignments — every time the Director needs an ADR created.

**The same pattern applies to:**
- Feature implementation (design → review → implement → test → gate)
- Bug fixes (triage → hotfix → document → verify)
- The shipping gate (8-step verification sequence)

Each time, the Director writes the same action DAG from scratch. This is repetitive, error-prone, and wastes tokens.

### Key Forces

1. **Templates must be parameterized.** Not every ADR needs a second opinion. Not every implement needs all tests. Templates must support optional steps.
2. **Templates must be evolvable.** As KodeHold's workflows change, templates must be updatable without breaking in-flight flows.
3. **Templates are action DAGs, not scripts.** A routine template is a graph of actions with dependencies — not a linear script. Agentmemory's `memory_routine_run` creates actions with proper `requires` chains.
4. **Graceful degradation.** If agentmemory doesn't support `memory_routine_run`, the Director falls back to manual action creation.
5. **Error handling.** If a template instantiation fails mid-way (e.g., action 3 of 6 can't be created), already-created actions must be cleaned up or marked as cancelled.

### Prior Art

- **ADR-0031** (Actions + Crystals for Director Delegation) — established the action model that templates build on
- **ADR-0029** (ICM → Agentmemory Migration Strategy) — Phase 4 of the migration plan; this ADR implements that phase
- **Actions+Crystals design doc** (`docs/design/actions-crystals-integration.md`, Section 8) — defines the 4 template DAGs
- **ADR-0017** (Reviewers as Gatekeeper) — review flow is captured in `kodehold-implement-flow`
- **ADR-0006** (Second Opinion Protocol) — second opinion step is captured in `kodehold-adr-flow`
- **`scripts/ship.sh`** — the 7 automated shipping steps are captured in `kodehold-ship-gate`

## Decision

### Implement 4 Routine Templates

Define 4 standard flow templates in agentmemory, accessible via `memory_routine_run`:

#### 1. `kodehold-adr-flow` (6 steps)

Purpose: Create a new ADR with full review lifecycle.

```
Step  Team          Action        Depends On      Priority  Optional?
────  ────────────  ────────────  ──────────────  ────────  ────────
 1    architects    research      (none)          8         No
 2    architects    write-adr     research        8         No
 3    scribes       design-doc    write-adr       5         No
 4    reviewers     review-adr    write-adr       7         No
 5    second-opinion cross-validate write-adr     7         Yes
 6    scribes       finalize      review-adr,     5         No
                                  cross-validate*
                                  
* Requirements adjusted if step 5 is skipped
```

Parameterization:
- `title` — ADR title (used in action descriptions)
- `require_second_opinion` — boolean (default: true for Architects tasks)
- `reviewers_team` — string (default: "reviewers")

#### 2. `kodehold-implement-flow` (6 steps)

Purpose: Implement a feature from design through testing.

```
Step  Team          Action           Depends On          Priority  Optional?
────  ────────────  ───────────────  ──────────────────  ────────  ────────
 1    architects    design           (none)              8         No
 2    reviewers     design-review    design              7         No
 3    engineers     implement        design-review       8         No
 4    reviewers     code-review      implement           7         No
 5    testers       test             implement           6         No
 6    reviewers     gate-validation  code-review, test   9         No
```

Parameterization:
- `feature_description` — used in action descriptions
- `skip_design_review` — boolean (default: false for trivial changes)
- `test_level` — "unit", "integration", or "full" (default: "full")

#### 3. `kodehold-bugfix-flow` (5 steps, with branching)

Purpose: Fix a bug with triage-first branching.

```
Step  Team    Action        Depends On  Priority  Condition
────  ──────  ────────────  ──────────  ────────  ─────────
 1    fls     triage        (none)      7         Always
 2a   fls     hotfix        triage      8         If minor bug (triage severity < 7)
 2b   ─      → REOPEN gate  triage      —        If major bug (triage severity ≥ 7)
 3    scribes document      hotfix*     5         If minor path taken
 4    reviewers verify      hotfix*     7         If minor path taken
     
* Requirements adjusted based on which branch was taken
```

Parameterization:
- `issue_ref` — issue/bug number or description
- `severity_threshold` — number (default: 7) above which REOPEN gate is triggered

#### 4. `kodehold-ship-gate` (7 steps)

Purpose: Execute the full shipping gate sequence.

```
Step  Team      Action              Depends On  Priority  Description
────  ────────  ──────────────────  ──────────  ────────  ──────────────────────────
 1    director  team-meeting        (none)      9         Step 0: Team meeting sign-off
 2    director  version-check       step-1      9         Step 1: VERSION.md exists
 3    director  changelog-check     step-1      9         Step 2: CHANGES.md exists
 4    director  todo-check          step-1      9         Step 3: TODO.md exists
 5    testers   test-suite          step-1      9         Step 4: Full test suite passes
 6    director  icm-check           step-1      9         Step 5: Agentmemory check
 7    director  git-status          step-1      9         Step 6: Git status clean
 8    director  branch-check        step-1      9         Step 7: Branch check
```

Note: Steps 2-8 depend on step 1 (team meeting completed) but are otherwise parallel. This is a fan-out DAG followed by a final manual step (PR/tag/release).

### Template Registration

Templates are registered in agentmemory via a structured format:

```
Routine ID: kodehold-adr-flow
Version: 1.0
Description: Create an ADR with full review lifecycle
Category: design
Author: Architects
Created: 2026-05-31
Steps: [array of step definitions with team, action type, dependencies, priority, optional flag]
```

The exact storage mechanism is defined by agentmemory's `memory_routine_run` implementation. If a native registration API is not available, templates can be stored as structured memories or in a dedicated slot.

### What This Changes

- **Director agent file:** Add routine trigger detection — recognize common patterns and offer `memory_routine_run` instantiation
- **Director delegation loop:** Reduce multi-step delegation to single `memory_routine_run` call for standard flows
- **Actions+Crystals design doc:** Update Section 8 with final template definitions
- **No changes to other agents** — templates create actions that are delegated to teams the same way as manual actions

## Consequences

### Positive

1. **Single-call workflow instantiation.** 6 `memory_action_create` calls become 1 `memory_routine_run` call. Significant token savings for standard flows.
2. **Consistent dependency graphs.** Every ADR flow uses the same DAG. No manual errors in `requires` chains.
3. **Automatic fan-out/fan-in.** The implement flow's parallel test + code-review fan-in is handled by the template, not constructed manually.
4. **Parameterized optional steps.** Second opinion, design review, and branching bugfix paths are built into the template.
5. **Versioned workflows.** Templates have version numbers. When workflows evolve, old templates remain for in-flight flows while new templates are created for new flows.
6. **Reduced Director logic.** Template instantiation replaces the Director's ad-hoc workflow construction logic.

### Negative

1. **Template maintenance overhead.** 4 templates × N steps each = ongoing maintenance. When KodeHold's workflows change, templates must be updated.
2. **Rigidity for edge cases.** Not every implementation fits the 6-step `kodehold-implement-flow`. Templates must be skipped for non-standard work.
3. **Parameter explosion danger.** As more options are added, templates become complex to use. Mitigation: keep parameters minimal (2-3 per template).
4. **Agentmemory dependency.** `memory_routine_run` must be available. If agentmemory doesn't support it, the Director falls back to manual action creation.
5. **Template discovery.** The Director must know template IDs. Mitigation: document template IDs in the agent definition.

### Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Template drift** — templates become outdated as workflows evolve | Medium | Medium | Version template IDs (kodehold-adr-flow-v1, etc.). Deprecate old versions. |
| 2 | **Partial instantiation failure** — only 3 of 6 actions created before error | Low | High | Implement transactional creation or cancel created actions on failure. |
| 3 | **Over-fitted templates** — templates optimized for ideal case, not real-world branching | Medium | Low | Keep templates simple. Complex workflows use manual action creation. |
| 4 | **No native `memory_routine_run`** — agentmemory may not support this yet | Medium | Medium | Store templates as structured data in a slot. Director reads slot and creates actions manually in a loop. |

### Follow-up Items

- [ ] Verify agentmemory supports `memory_routine_run` — if not, implement slot-based template storage fallback
- [ ] Register 4 templates with agentmemory
- [ ] Update `.opencode/agents/director.md` — add routine trigger patterns and template ID reference
- [ ] Update `docs/design/actions-crystals-integration.md` Section 8 with final template definitions
- [ ] Create template parameter documentation for the Director

### How to Revert

1. Stop calling `memory_routine_run`. Fall back to manual `memory_action_create` per action (Phase 3 style).
2. Templates remain registered in agentmemory but are unused.
3. This ADR becomes Deprecated. Reactivate manual action creation.

## ADR References

- **ADR-0031** (Actions + Crystals for Director Delegation) — establishes the action model that templates build on. Templates are parameterized action DAGs.
- **ADR-0029** (ICM → Agentmemory Migration Strategy) — Phase 4 of the migration plan; this ADR implements that phase.
- **ADR-0017** (Reviewers as Gatekeeper) — review flow captured in `kodehold-implement-flow`
- **ADR-0006** (Second Opinion Protocol) — second opinion step captured in `kodehold-adr-flow`
- **ADR-0033** (Inter-Agent Signals + Sentinels) — downstream; signals can trigger template instantiation
- **Actions+Crystals design doc** (`docs/design/actions-crystals-integration.md`, Section 8) — template DAG definitions
- **`scripts/ship.sh`** — shipping gate steps captured in `kodehold-ship-gate`

### Source Files Referenced

- `docs/design/actions-crystals-integration.md` — Section 8: Routine Templates (4 template DAGs)
- `.opencode/agents/director.md` — delegation loop to be extended with routine triggers
- `scripts/ship.sh` — shipping gate steps 1-7
- `docs/adr/ADR-0006-second-opinion.md` — second opinion protocol referenced by ADR flow
- `docs/adr/ADR-0017-reviewers-gatekeeper-and-mandatory-second-opinion.md` — review gate referenced by implement flow
