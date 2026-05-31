# Impact Analysis: ICM → Agentmemory Migration + Actions/Crystals Integration

**Author:** Architects  
**Date:** 2026-05-31  
**Context:** CLOSED → REOPEN transition for KodeHold  
**Status:** Analysis Complete  

---

## 1. Executive Summary

This impact analysis covers two tightly coupled migrations:

1. **ICM → Agentmemory** — Replace all Infinite Context Memory (ICM) operations with pure agentmemory equivalents across 31+ files (8 agent definitions, 2 skills, 1 design doc, 9 ADRs, 4 scripts, 2 config files, 2 reference files, 3 support files).

2. **Actions + Crystals** — Integrate agentmemory's orchestration layer (actions, dependencies, leases, frontiers, routines, signals, crystals) into the Director's delegation flow, replacing manual `todowrite` lists and ad-hoc checkpoint management.

The existing draft design (`docs/design/actions-crystals-integration.md`, v0.1) defines 6 migration phases. This analysis maps every file change to those phases and identifies all dependencies.

**Total files affected:** ~31+  
**Total ADRs affected:** 9 (4 to deprecate, 3 to rewrite, 2 to update)  
**Estimated effort:** 4-6 phases across 2-4 implementation sessions  

---

## 2. Scope of Work — Complete File Inventory

### 2.1 Agent Files (8 files, ~120 ICM references combined)

| File | ICM References | Impact | Migration Phase |
|------|---------------|--------|-----------------|
| `.opencode/agents/director.md` | ~35 | Replace all `icm *` commands with `memory_*` MCP tools. Replace "ICM Protocol" section with "Agentmemory Protocol". Replace todo`write` delegation with `memory_frontier` + `memory_lease` flow. Remove `"icm *": allow` bash permission. | Phase 3 |
| `.opencode/agents/scribes.md` | ~55 | Rewrite entire "ICM Database", "ICM Best Practices", "ICM Knowledge Flow" sections for agentmemory. Replace `icm_memory_*` calls with `memory_*` equivalents. Rewrite session checkpoint, compression, CLOSED distillation, and prospective memory workflows. | Phase 2 |
| `.opencode/agents/architects.md` | ~5 | Replace "ICM Knowledge Flow" with "Agentmemory Knowledge Flow". Replace `icm memoir search-all` with `memory_smart_search` or `memory_recall`. | Phase 1 |
| `.opencode/agents/engineers.md` | ~5 | Replace "ICM Knowledge Flow" with "Agentmemory Knowledge Flow". | Phase 1 |
| `.opencode/agents/reviewers.md` | ~5 | Replace "ICM Knowledge Flow" with "Agentmemory Knowledge Flow". | Phase 1 |
| `.opencode/agents/testers.md` | ~4 | Replace "ICM Knowledge Flow" with "Agentmemory Knowledge Flow". | Phase 1 |
| `.opencode/agents/fls.md` | ~12 | Replace "ICM Knowledge Flow". Replace `icm_memory_recall` calls with `memory_recall`. Replace project discovery workflow (was using `icm_memory_list_topics`). | Phase 2 |
| `.opencode/agents/second-opinion.md` | ~3 | Replace "ICM Knowledge Flow" with "Agentmemory Knowledge Flow". | Phase 1 |

### 2.2 Skills (2 files)

| File | ICM References | Impact | Phase |
|------|---------------|--------|-------|
| `.opencode/skills/icm-knowledge-flow/SKILL.md` | ~40 (entire file) | **Rename** to `agentmemory-knowledge-flow/SKILL.md`. Replace all `icm_memory_*` and `icm_memoir_*` tool calls with `memory_*` equivalents. Maintain 3-mode structure (Pre-task/Post-task/Full). Update topic conventions. | Phase 2 |
| `.opencode/skills/investigate/SKILL.md` | 3 (Phase 5) | Replace "Store findings in ICM" section with agentmemory store. Update topic convention. | Phase 1 |

### 2.3 Design Documents (2 files)

| File | ICM References | Impact | Phase |
|------|---------------|--------|-------|
| `docs/design/README.md` | ~25 | Update Principle #4 ("ICM stores..." → "Agentmemory stores..."). Rewrite Section 7.2 (ICM → Agentmemory). Update Section 7.4 (Skills — rename icm-knowledge-flow reference). Update ADR index. Bump to v2.0.0 (major change — infrastructure replacement). | Phase 3 |
| `docs/design/actions-crystals-integration.md` | 0 (draft, v0.1) | Promote to v1.0.0 Active. This draft becomes the implementation plan for the migration. Fill in remaining sections. | Phase 1 |

### 2.4 ADRs (9 affected)

| ADR | Current Status | ICM Content | Required Action | Phase |
|-----|---------------|-------------|-----------------|-------|
| ADR-0004 | Accepted | Foundational: "ICM and RTK Integration Strategy" | **Deprecate** — superseded by ADR-0029+ (agentmemory integration) | Phase 3 |
| ADR-0009 | Accepted | "ICM MCP Integration" — defines layered ICM architecture | **Deprecate** — superseded by direct agentmemory API | Phase 3 |
| ADR-0019 | Accepted | "Session Context Compression via ICM Summaries" | **Write new ADR** — migrate compression to agentmemory; mark ADR-0019 as Superseded | Phase 3 |
| ADR-0020 | Superseded | Hierarchical Memory (already superseded by ICM) | **No change** — already superseded; agentmemory has its own importance system | — |
| ADR-0021 | Accepted | "Prospective Memory" — tasks stored in ICM | **Rewrite** — migrate to agentmemory actions + `memory_recall`; mark ADR-0021 as Superseded by ADR-0031 | Phase 3 |
| ADR-0022 | Superseded | Automated Episodic Extraction | **No change** — already superseded by ICM | — |
| ADR-0023 | Superseded | Semantic Memory Automation | **No change** — already superseded by ICM | — |
| ADR-0025 | Deprecated | A2A Protocol | **Re-evaluate** — agentmemory `memory_signal` makes inter-agent messaging viable. Consider reviving. | Phase 5 |
| ADR-0027 | Proposed | "ICM Knowledge Flow Invocation Modes" | **Deprecate** — replaced by "Agentmemory Knowledge Flow" (ADR-0030). Write new ADR for agentmemory version. | Phase 3 |

**New ADRs required:**
| # | Title | Content | Phase |
|---|-------|---------|-------|
| ADR-0029 | Agentmemory Migration Strategy | Overall migration approach, tool mapping, rollback plan | Phase 1 |
| ADR-0030 | Agentmemory Knowledge Flow | Replacement for ADR-0027 — Pre-task/Post-task/Full modes using `memory_*` tools | Phase 2 |
| ADR-0031 | Agentmemory Actions + Crystals Integration | Director delegation with `memory_action_create`, `memory_frontier`, `memory_lease` | Phase 3 |
| ADR-0032 | Routine Templates | Standard flows (ADR, implement, bugfix, ship) as `memory_routine_run` templates | Phase 4 |
| ADR-0033 | Agentmemory Signals for Inter-Agent Coordination | Replacement for deprecated A2A Protocol (ADR-0025) | Phase 5 |

### 2.5 Scripts (4 files)

| File | ICM References | Impact | Phase |
|------|---------------|--------|-------|
| `scripts/gate.sh` | 4 | Replace `icm stats` with agentmemory health check (`memory_health` or equivalent) | Phase 2 |
| `scripts/ship.sh` | 8 | Replace Step 5 "ICM Check" with "Agentmemory Check". Replace store release step. | Phase 2 |
| `scripts/benchmark.sh` | ~25 (entire file) | Rewrite for agentmemory performance benchmarks. Or deprecate (agentmemory may not expose low-level bench). | Phase 3 |
| `scripts/consolidate-all.sh` | ~20 (entire file) | Rewrite for agentmemory. Or deprecate (agentmemory has auto-consolidation). | Phase 3 |

### 2.6 Config & Reference Files (5 files)

| File | ICM References | Impact | Phase |
|------|---------------|--------|-------|
| `opencode.json` | 1 | Replace `"icm *": allow` with `"memory_*": allow` in Director's bash permissions | Phase 2 |
| `.gitignore` | 1 | Keep `.icm/` entry (legacy data) or remove if directory is deleted | Phase 6 |
| `.opencode/references/kodehold-protocol.md` | 5 | Replace "ICM Topic Convention" with "Agentmemory Topic Convention". Update quality/shipping gate checks. | Phase 2 |
| `AGENTS.md` | 3 | Update quick reference: remove "Always load ICM context", "Always store decisions in ICM". Update shipping gate check name. | Phase 2 |
| `.kodehold-state` | 0 | No change needed (no ICM references) | — |

### 2.7 Support Files (3 files)

| File | ICM References | Impact | Phase |
|------|---------------|--------|-------|
| `CHANGES.md` | ~5 | Will be updated naturally as migration progresses | Ongoing |
| `VERSION.md` | ~5 | Will be updated naturally as migration progresses | Ongoing |
| `TODO.md` | ~0 | Will be updated as implementation tasks are created | Ongoing |

---

## 3. Migration Phases (Mapped to Actions-Crystals Design)

The following phases are defined in `docs/design/actions-crystals-integration.md` (Section 11). Each phase below is annotated with the specific files that change.

### Phase 1: Awareness — Fire-and-Forget Action Creation

**Goal:** Create agentmemory actions alongside existing workflow. No behavioral change. Establish agentmemory infrastructure.

**Files to change:**
| File | Change |
|------|--------|
| `docs/design/actions-crystals-integration.md` | Promote v0.1 → v1.0.0 Active. Finalize all 16 sections. |
| New: `docs/adr/ADR-0029-agentmemory-migration-strategy.md` | Write. Define overall approach: tools mapping (icm_* → memory_*), rollback plan, coexistence rules. |
| `.opencode/agents/director.md` | Add parallel action creation: after each delegation round, create corresponding `memory_action_create` with dependency chain. Existing todowrite sequence unchanged. |
| `.opencode/agents/scribes.md` | Add agentmemory parallel store: after each ICM store, also store via `memory_save`. No behavioral change yet. |

**Key changes in Director flow (additive, not replacement):**
```
# Before:
delegate → todowrite update → store in ICM

# After:
delegate → todowrite update → memory_action_create → store in ICM + memory_save
```

**Deliverables:**
- [ ] ADR-0029 written and accepted
- [ ] Actions design doc promoted to Active
- [ ] Director creates actions alongside delegations (dual-write)
- [ ] Scribes dual-writes to agentmemory
- [ ] All teams can access agentmemory via `memory_recall`

**Estimated effort:** 1 implementation session

---

### Phase 2: Infrastructure Migration — ICM → Agentmemory

**Goal:** Replace all ICM MCP tools with agentmemory equivalents. Rename skills. Remove dual-write. Single-source on agentmemory.

**Files to change:**
| File | Change |
|------|--------|
| `.opencode/skills/icm-knowledge-flow/SKILL.md` | **Rename directory** to `agentmemory-knowledge-flow/`. Rewrite all tool calls. Maintain 3-mode structure. |
| `.opencode/skills/investigate/SKILL.md` | Replace "Store findings in ICM" with agentmemory. |
| `.opencode/agents/architects.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". Replace `icm memoir search-all` with `memory_smart_search`. |
| `.opencode/agents/engineers.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". |
| `.opencode/agents/reviewers.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". |
| `.opencode/agents/testers.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". |
| `.opencode/agents/fls.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". Replace `icm_memory_list_topics` with agentmemory equivalent (`memory_recent` or list). |
| `.opencode/agents/second-opinion.md` | Replace "ICM Knowledge Flow" → "Agentmemory Knowledge Flow". |
| `.opencode/agents/scribes.md` | **Major rewrite**: Replace entire "ICM Database", "ICM Best Practices", "ICM Knowledge Flow" sections. Rewrite session checkpoint (use `memory_save` instead of `icm_memory_store`). Rewrite session compression (use `memory_save` to topic). Rewrite CLOSED distillation (use `memory_recall` + agentmemory's concept extraction). Rewrite prospective memory (use `memory_save`). |
| `.opencode/agents/director.md` | Remove dual-write. Single-source on agentmemory. Move from "ICM Protocol" to "Agentmemory Protocol". Replace `"icm *": allow` with `"memory_*": allow`. |
| `opencode.json` | Update Director bash permissions. |
| `scripts/gate.sh` | Replace `icm stats` check with agentmemory health check. |
| `scripts/ship.sh` | Replace Step 5 "ICM Check" with "Agentmemory Check". Replace release store step. |
| `.opencode/references/kodehold-protocol.md` | Replace "ICM Topic Convention" with "Agentmemory Topic Convention". Update quality/shipping gate checks. |
| `AGENTS.md` | Update quick reference. Update shipping gate. |
| New: `docs/adr/ADR-0030-agentmemory-knowledge-flow.md` | Write. Replace ADR-0027. Define 3-mode agentmemory knowledge flow. |
| New: `.opencode/skills/agentmemory-knowledge-flow/README.md` | Create. Document the renamed skill. |

**Key mapping (ICM → Agentmemory):**

| ICM Tool | Agentmemory Equivalent | Notes |
|----------|----------------------|-------|
| `icm_memory_store` | `memory_save` | Same semantics: store with content, project, type |
| `icm_memory_recall` | `memory_recall` | Hybrid search (semantic + keyword) |
| `icm_memoir_search` | `memory_lesson_recall` | Query lessons database |
| `icm_memoir_search_all` | `memory_smart_search` | Cross-source search |
| `icm_memory_consolidate` | `memory_consolidate` | Same concept |
| `icm_memory_extract_patterns` | `memory_patterns` | Pattern detection |
| `icm_memoir_refine` | `memory_lesson_save` | Store refined lessons |
| `icm_memory_health` | `memory_diagnose` | System health check |
| `icm_memory_forget` | `memory_governance_delete` | Memory deletion |

**Deliverables:**
- [ ] ADR-0030 written and accepted
- [ ] `agentmemory-knowledge-flow` skill created, `icm-knowledge-flow` deprecated
- [ ] All 8 agent files updated: ICM references replaced with agentmemory
- [ ] Scribes fully migrated: all workflows use agentmemory only
- [ ] gate.sh and ship.sh use agentmemory health checks
- [ ] kodehold-protocol.md updated
- [ ] AGENTS.md updated
- [ ] Dual-write removed — single source on agentmemory

**Estimated effort:** 1-2 implementation sessions (scribes.md is the largest single change)

---

### Phase 3: Frontier-Driven Delegation — Replace todowrite with Actions

**Goal:** Replace the Director's manual `todowrite` sequence protocol with agentmemory's action orchestration layer. The Director reads `memory_frontier` instead of maintaining sequential todo lists.

**Files to change:**
| File | Change |
|------|--------|
| `.opencode/agents/director.md` | **Replace "Todo Sequence Protocol" section** with "Action Frontier Protocol". Replace delegation loop: instead of `todowrite` → delegate → mark done, now: `memory_action_create` (with `requires` deps) → `memory_frontier` (get next unblocked) → `memory_lease` (acquire lock) → delegate → `memory_action_update` (mark done, set `result`) → release lease. |
| `.opencode/agents/scribes.md` | Add post-task action management: update action status, crystallize completed chains. |
| `docs/design/README.md` | Update Section 5 to reference Actions-based workflow. Add new integration subsection in Section 7. |
| New: `docs/adr/ADR-0031-agentmemory-actions-crystals.md` | Write. Define action types, dependency model, frontier flow, crystal strategy. |
| `docs/adr/ADR-0004-icm-rtk-integration.md` | Deprecate. Cross-reference ADR-0031. |
| `docs/adr/ADR-0009-icm-mcp-integration.md` | Deprecate. Cross-reference ADR-0031. |
| `docs/adr/ADR-0019-session-context-compression.md` | Supersede. Write new ADR for compression via agentmemory. |
| `docs/adr/ADR-0021-prospective-memory.md` | Supersede. Migrate to actions-based tasks. |
| `docs/adr/ADR-0027-icm-knowledge-flow-invocation-modes.md` | Deprecate. Replaced by ADR-0030. |
| `scripts/benchmark.sh` | Rewrite for agentmemory or deprecate. |
| `scripts/consolidate-all.sh` | Deprecate (agentmemory auto-consolidates). |

**Director's new delegation loop (simplified):**
```
# Old (todowrite):
1. Create todowrite sequence
2. Delegate to team
3. Update todowrite status
4. Repeat

# New (actions + frontier):
1. memory_action_create(type="implement", requires=["design-done"])
2. memory_frontier → returns unblocked actions sorted by priority
3. memory_lease(action_id) → acquire exclusive lock
4. Delegate to team
5. memory_action_update(action_id, status="done", result="summary")
6. memory_lease(action_id) → release
7. memory_crystallize(completed_chain) → auto-summarize
```

**Action Types (from design doc):**
| Type | Priority | Team |
|------|----------|------|
| `design` | 8 | architects |
| `review` | 7 | reviewers |
| `implement` | 8 | engineers |
| `test` | 6 | testers |
| `gate-validation` | 9 | reviewers |
| `gate-execution` | 9 | director |
| `document` | 5 | scribes |
| `triage` | 7 | fls |
| `ship` | 9 | director |

**Deliverables:**
- [ ] ADR-0031 written and accepted
- [ ] Director's Todo Sequence Protocol replaced with Action Frontier Protocol
- [ ] `memory_frontier` drives delegation decisions
- [ ] `memory_lease` prevents double-delegation
- [ ] `memory_crystallize` generates automated digests
- [ ] ADR-0004 deprecated
- [ ] ADR-0009 deprecated
- [ ] ADR-0019 superseded (new compression ADR)
- [ ] ADR-0021 superseded (migrated to actions)
- [ ] ADR-0027 deprecated
- [ ] benchmark.sh rewritten or deprecated
- [ ] consolidate-all.sh deprecated

**Estimated effort:** 1-2 implementation sessions (director.md is the largest change)

---

### Phase 4: Routine Templates — Standard Flows Automated

**Goal:** Define 4 standard flow templates as `memory_routine_run` templates. Each template reduces the Director's delegation loop to a single `memory_routine_run` call.

**Files to change:**
| File | Change |
|------|--------|
| `.opencode/agents/director.md` | Add routine triggers: detect common patterns and offer template instantiation. |
| New: `docs/adr/ADR-0032-agentmemory-routine-templates.md` | Write. Define 4 templates with action DAGs. |
| `docs/design/actions-crystals-integration.md` | Update Section 8 with final template definitions. |

**Standard Flow Templates (from design doc):**

**kodehold-adr-flow** (6 steps):
```
1. architects: research (no deps)
2. architects: write-adr (requires: research)
3. scribes: design-doc-update (requires: write-adr)
4. reviewers: review-adr (requires: write-adr)
5. second-opinion: cross-validate (requires: write-adr)
6. scribes: finalize (requires: review-adr, cross-validate)
```

**kodehold-implement-flow** (6 steps):
```
1. architects: design (no deps)
2. reviewers: design-review (requires: design)
3. engineers: implement (requires: design-review)
4. reviewers: code-review (requires: implement)
5. testers: test (requires: implement)
6. reviewers: gate-validation (requires: code-review, test)
```

**kodehold-bugfix-flow** (5 steps, with branching):
```
1. fls: triage (no deps)
   ├── [minor] fls: hotfix (requires: triage)
   └── [major] → REOPEN gate → implement-flow
2. scribes: document (requires: hotfix)
3. reviews: verify (requires: hotfix)
```

**kodehold-ship-gate** (7 steps):
```
1-7: Corresponds to ship.sh steps 0-6
```

**Deliverables:**
- [ ] ADR-0032 written and accepted
- [ ] 4 routine templates stored in agentmemory
- [ ] Director can instantiate flows with `memory_routine_run`
- [ ] Templates reduce manual delegation overhead

**Estimated effort:** 1 implementation session

---

### Phase 5: Crystals + Signals — Advanced Orchestration

**Goal:** Implement automatic crystallization of completed work chains. Enable inter-agent signaling via `memory_signal_send`/`memory_signal_read`. Re-evaluate A2A Protocol (ADR-0025).

**Files to change:**
| File | Change |
|------|--------|
| `.opencode/agents/director.md` | Add crystal trigger: after action chains complete, auto-crystallize. Add signal routing: delegate based on signals. |
| `.opencode/agents/scribes.md` | Add crystal consumption workflow: extract lessons from crystals. |
| New: `docs/adr/ADR-0033-agentmemory-signals.md` | Write. Define signal types, routing rules, replaces ADR-0025. |
| `docs/adr/ADR-0025-a2a-protocol.md` | Re-evaluate. Either formally close with "Replaced by agentmemory signals" or revive. |

**Crystal Strategy (from design doc):**
- **Per-flow** — crystallize after each completed flow template (every action in chain done)
- **Per-checkpoint** — crystallize at state transitions (gate passes)
- **Per-trigger** — crystallize when `memory_action_create` with `crystallize: true` is set

**Signal Types (proposed):**
| Signal | Purpose | Example |
|--------|---------|---------|
| `info` | Status notification | "Design complete" |
| `request` | Ask for input | "Review needed" |
| `response` | Reply to request | "Review approved" |
| `alert` | Problem notification | "Test failure" |
| `handoff` | Transfer responsibility | "Taking over issue X" |

**Deliverables:**
- [ ] ADR-0033 written and accepted
- [ ] Auto-crystallization implemented
- [ ] Inter-agent signals operational
- [ ] ADR-0025 formally closed

**Estimated effort:** 1 implementation session

---

### Phase 6: Backward Compatibility & Cleanup

**Goal:** Verify all fallback paths work. Clean up legacy ICM references. Validate light mode (KODEHOLD_LIGHT=1). Remove dual-write artifacts.

**Files to change:**
| File | Change |
|------|--------|
| `.gitignore` | Remove `.icm/` entry if directory is deleted. |
| All agent files | Final cleanup pass — ensure no ICM references remain. |
| All script files | Final cleanup pass. |
| `CHANGES.md` | Add migration completion entry. |
| `VERSION.md` | Bump to appropriate version. |

**Verification checklist:**
- [ ] Zero ICM references remain in any active file
- [ ] All agent definitions use `memory_*` tools exclusively
- [ ] gate.sh passes without ICM installed
- [ ] ship.sh passes without ICM installed  
- [ ] KODEHOLD_LIGHT=1 path uses agentmemory summaries (was ICM summaries)
- [ ] `.icm/` directory can be safely removed
- [ ] Rollback instructions documented (ADR-0031 consequences section)

**Estimated effort:** 1 implementation session (cleanup + verification)

---

## 4. Complete Tool Mapping: ICM → Agentmemory

This table is the definitive translation guide for the entire migration:

| ICM Tool | Agentmemory Tool | Notes |
|----------|-----------------|-------|
| `icm_memory_store` | `memory_save` | Map `topic` → `project` + patterns; `importance` → `type` |
| `icm_memory_recall` | `memory_recall` | Semantic search; use `query` + `limit` |
| `icm_memory_update` | `memory_save` (same id) | Overwrite existing memory |
| `icm_memory_forget` | `memory_governance_delete` | Requires `reason` parameter |
| `icm_memory_consolidate` | `memory_consolidate` | Same concept; tier parameter |
| `icm_memory_list_topics` | `memory_slot_list` + `memory_recall` | No direct equivalent; use multiple recalls |
| `icm_memory_stats` | `memory_diagnose` | Health check |
| `icm_memory_health` | `memory_diagnose` | Health check |
| `icm_memory_embed_all` | N/A | Auto-embedding in agentmemory |
| `icm_memoir_create` | N/A | Use `memory_save` with type |
| `icm_memoir_list` | `memory_slot_list` | No direct equivalent |
| `icm_memoir_show` | `memory_recall` | Query by concept name |
| `icm_memoir_add_concept` | `memory_lesson_save` | Lessons are the agentmemory equivalent of concepts |
| `icm_memoir_refine` | `memory_lesson_save` (same content) | Update existing lesson |
| `icm_memoir_search` | `memory_lesson_recall` | Query lessons |
| `icm_memoir_search_all` | `memory_smart_search` | Cross-source hybrid search |
| `icm_memoir_link` | `memory_facet_tag` | Tagging provides linking |
| `icm_memoir_inspect` | `memory_verify` | Provenance tracking |
| `icm_memory_extract_patterns` | `memory_patterns` | Pattern detection |
| `icm_cli: store` | `memory_save` | CLI → MCP |
| `icm_cli: recall` | `memory_recall` | CLI → MCP |
| `icm_cli: stats` | `memory_diagnose` | CLI → MCP |
| — (new) | `memory_action_create` | **New** — action orchestration |
| — (new) | `memory_action_update` | **New** — action status management |
| — (new) | `memory_frontier` | **New** — dependency-ordered work queue |
| — (new) | `memory_lease` | **New** — exclusive action lock |
| — (new) | `memory_crystallize` | **New** — compress action chains |
| — (new) | `memory_routine_run` | **New** — standard workflow templates |
| — (new) | `memory_signal_send` | **New** — inter-agent messaging |
| — (new) | `memory_signal_read` | **New** — read messages |
| — (new) | `memory_sentinel_create` | **New** — event-driven gating |
| — (new) | `memory_sentinel_trigger` | **New** — fire sentinel |
| — (new) | `memory_sketch_create` | **New** — ephemeral investigation |
| — (new) | `memory_sketch_promote` | **New** — make ephemeral permanent |

---

## 5. Risks and Mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Data loss** — Existing ICM memories orphaned after migration | Medium | High | Phase 6 explicitly adds rollback instructions. Keep `.icm/` directory read-only during transition. Agentmemory can coexist — migrate gradually. |
| 2 | **Director behavior regression** — Replacing todo`write` with `memory_frontier` breaks delegation flow | Medium | Critical | Phase 1 (Awareness) dual-writes actions AND todowrite. Director can fall back to todowrite if frontier returns unexpected results. |
| 3 | **Team agent confusion** — "ICM Knowledge Flow" → "Agentmemory Knowledge Flow" rename breaks references | Low | Medium | All agent files updated in Phase 2 simultaneously. The skill directory rename must be atomic. |
| 4 | **Agent permission gaps** — Director's `"icm *": allow` removed but `"memory_*": allow` not configured | Low | High | Update `opencode.json` Director permissions in Phase 2 before removing ICM references. Test with `memory_diagnose` first. |
| 5 | **Script breakage** — gate.sh and ship.sh fail without ICM installed | Medium | High | Phase 2 adds agentmemory health check before removing ICM check. Graceful degradation: warn if neither is available. |
| 6 | **Phase overrun** — Scribes migration (Phase 2) touches ~55 ICM references in a single agent file | Medium | Medium | Split scribes.md migration into sub-tasks: (a) Knowledge Flow section, (b) Database/Best Practices, (c) Workflows (checkpoint, compression, distillation, prospective), (d) CRUD operations. |
| 7 | **Legacy data in `.icm/`** — Old memories are still valuable but agentmemory can't read them | Medium | Medium | Consider a one-time migration script: `memory_save` for each critical/high ICM memory. Or keep `.icm/` directory as read-only archive. |
| 8 | **Scoping mismatch** — Agentmemory uses `project` parameter differently than ICM's topic prefix system | Low | Medium | ADR-0028 already resolved this: full filesystem path is the project name. All agentmemory calls use `project=process.cwd()`. |
| 9 | **ADRs 0004/0009 deprecation cascading** — Other ADRs reference them | Medium | Low | Each new ADR (0029-0033) explicitly lists which prior ADRs it supersedes. ADR index in design doc is updated atomically. |
| 10 | **KODEHOLD_LIGHT=1 path** — Light mode currently uses "ICM summaries" | Low | Medium | Phase 6 explicitly tests light mode with agentmemory. Replace "ICM summaries" with "agentmemory summaries" in all agent files. |
| 11 | **ICM MCP server dependency** — Current architecture depends on `icm serve` running | Low | Medium | Agentmemory daemon (`iii`) must be running. This is already a dependency. No new infrastructure needed. |

---

## 6. Effort Estimate

| Phase | Name | Files Changed | New ADRs | Est. Sessions | Risk |
|-------|------|--------------|----------|---------------|------|
| 1 | Awareness | 4 | 1 | 1 | Low |
| 2 | Infrastructure Migration | 15+ | 1 | 1-2 | Medium |
| 3 | Frontier-Driven Delegation | 7+ | 1 | 1-2 | High |
| 4 | Routine Templates | 3 | 1 | 1 | Medium |
| 5 | Crystals + Signals | 4 | 1 | 1 | Low |
| 6 | Backward Compatibility | 10+ | 0 | 1 | Low |

**Total: 6-8 implementation sessions across all phases**

**Dependency chain between phases:**
```
Phase 1 (Awareness) → Phase 2 (Infrastructure) → Phase 3 (Frontier)
                                                      ↓
Phase 5 (Crystals) → Phase 6 (Cleanup)           Phase 4 (Routines)
```
- Phase 2 must precede Phase 3 (no frontier without agentmemory)
- Phase 3 must precede Phase 4 (routines need actions)
- Phase 5 has soft dependency on Phase 3 (crystals work with actions)
- Phase 6 must be last (final cleanup)
- Phase 4 can be parallel with Phase 5

**Critical path:** Phase 1 → Phase 2 → Phase 3 → Phase 6

---

## 7. ADR Update Summary

### ADRs to Create (5 new):

| ADR | Title | Phase | Supersedes |
|-----|-------|-------|------------|
| ADR-0029 | Agentmemory Migration Strategy | 1 | — |
| ADR-0030 | Agentmemory Knowledge Flow | 2 | ADR-0027 |
| ADR-0031 | Agentmemory Actions + Crystals Integration | 3 | ADR-0004, ADR-0009 |
| ADR-0032 | Routine Templates for KodeHold | 4 | — |
| ADR-0033 | Agentmemory Signals for Inter-Agent Coordination | 5 | ADR-0025 (revive) |

### ADRs to Update (9 affected):

| ADR | Current Status | New Status | Change |
|-----|---------------|------------|--------|
| ADR-0004 | Accepted | Deprecated | Superseded by ADR-0031 |
| ADR-0009 | Accepted | Deprecated | Superseded by ADR-0031 |
| ADR-0019 | Accepted | Superseded | Content migrated, replaced by compression via agentmemory |
| ADR-0020 | Superseded | No change | Already superseded by ICM; cross-reference agentmemory |
| ADR-0021 | Accepted | Superseded | Migrate to actions-based tasks |
| ADR-0022 | Superseded | No change | Already superseded |
| ADR-0023 | Superseded | No change | Already superseded |
| ADR-0025 | Deprecated | Superseded or Revived | Target for ADR-0033 revival via signals |
| ADR-0027 | Proposed | Deprecated | Replaced by ADR-0030 |

### ADRs with No Change:
- ADR-0001 (Foundation) — No ICM references
- ADR-0002 (Organization) — No ICM references
- ADR-0003 (Design Lifecycle) — No ICM references
- ADR-0005 (LLM Support) — No ICM references
- ADR-0006 (Second Opinion) — No ICM references
- ADR-0007 (Token Optimization) — No ICM references
- ADR-0008 (Project Lifecycle) — No ICM references
- ADR-0010 (FLS) — No ICM references
- ADR-0011 (Team Meeting) — No ICM references
- ADR-0012 (Adopted Projects) — No ICM references
- ADR-0013 (Investigate Skill) — No ICM references
- ADR-0014 (Status Dashboard) — No ICM references
- ADR-0015 (Director Delegation) — No ICM references
- ADR-0016 (Early Review Gates) — No ICM references
- ADR-0017 (Reviewers Gatekeeper) — No ICM references
- ADR-0018 (Scribes Centralization) — No ICM references
- ADR-0024 (Shared Memory) — Already Deprecated; no change
- ADR-0026 (Second Opinion Bias) — No ICM references
- ADR-0028 (Agentmemory Project Detection) — Already references agentmemory; update to note migration completion

---

## 8. Director Delegation Flow: Before vs After

### Before (Current — todowrite + ICM)
```
1. Director maps task sequence
2. Director creates todowrite with pending/completed markers
3. Director delegates to team via Task tool
4. Team loads ICM context (Pre-task Knowledge Flow)
5. Team executes work
6. Director stores results in ICM via Scribes (Post-task)
7. Director updates todowrite status
8. Director stores checkpoint in ICM periodically
```

### After (Target — actions + frontier + agentmemory)
```
1. Director creates actions with dependency chain
   memory_action_create(type="design", requires=[], priority=8)
   memory_action_create(type="review", requires=["design-001"], priority=7)
2. Director reads frontier for next unblocked action
   memory_frontier → returns action with highest priority + no blockers
3. Director acquires lease on action
   memory_lease(action_id, "director") → exclusive lock
4. Director delegates to team via Task tool
5. Team loads context (Pre-task via memory_recall + memory_lesson_recall)
6. Team executes work
7. Director updates action with result
   memory_action_update(action_id, status="done", result="summary")
8. Director crystallizes completed chain
   memory_crystallize(chain_ids) → auto-digest
9. Director releases lease
   memory_lease(action_id, "director", operation="release")
10. For standard flows, one-shot instantiation:
    memory_routine_run(routine_id="kodehold-adr-flow")
```

---

## 9. Key Dependencies

### Prerequisites (Must Exist Before Starting)
- Agentmemory daemon (`iii`) running and accessible (confirmed via `memory_diagnose`)
- Director has `memory_*` bash permissions in `opencode.json`
- All 8 agent files have `memory_*` tools available via MCP
- ADR-0028 accepted (project detection — resolved: full path)

### Prerequisites Established by ADR-0028
- [x] Plugin reverted to original (no modifications)
- [x] Full filesystem path = canonical project name
- [x] Director has `process.cwd()` project resolution
- [x] No `getActiveProject()`, no slot injection needed

### Open Questions Before Starting Phase 1
- Should we keep `.icm/` as read-only archive (Phase 6) or run a one-time migration script?
- What is the agentmemory equivalent of `icm_memory_list_topics`? (No direct match — solution needed for FLS project discovery in Phase 2)
- Does agentmemory have a `memory_diagnose` equivalent for health checks in gate.sh? (Tool exists; verify response format)
- Does `memory_recall` support topic-scoped queries similar to ICM's `-t` flag? (Uses `project` parameter instead; verify equivalence)

---

## 10. Conclusion

The ICM → agentmemory migration with Actions + Crystals integration is a major infrastructure change affecting ~31+ files across the entire KodeHold codebase. It replaces the memory layer (ICM → agentmemory) and the orchestration layer (todowrite → actions), both of which are core to KodeHold's operation.

**The migration is structured into 6 phases** to ensure backward compatibility at every step. No phase breaks existing functionality — each phase adds capability before removing the old path. Phase 1 dual-writes, Phase 2 replaces infrastructure, Phase 3 rewires delegation, Phases 4-5 add new capabilities, and Phase 6 cleans up.

**Guidance for the Director:**
1. Execute phases sequentially (Phases 1→2→3→6 are the critical path; 4 and 5 can parallel)
2. Phase 2 (scribes.md rewrite) is the largest single-file change — budget extra time
3. Create ADRs before implementing each phase (ADR-0029 before Phase 1, etc.)
4. Test each phase independently before marking it complete
5. Update `.impact_analysis_done` has been created — this analysis is complete

**Version tracking:** The design doc should bump from v1.6.0 to v2.0.0 (major change — infrastructure replacement). Phase 6 finalizes the version bump.

---

## 11. Changelog

| Version | Date | Author | Change |
|---------|------|--------|--------|
| 1.0 | 2026-05-31 | Architects | Initial impact analysis for ICM → agentmemory migration + Actions/Crystals integration |
