# ADR-0030: Agentmemory Knowledge Flow (Replacing ICM Knowledge Flow)

## Status

Proposed

**Phase:** Phase 2 (Infrastructure Migration) — replaces ADR-0027 and the `icm-knowledge-flow` skill.

## Context

### The Problem

The current `icm-knowledge-flow` skill at `.opencode/skills/icm-knowledge-flow/SKILL.md` defines an 8-step protocol that all 6 team agents execute on every delegation. The skill is referenced by every agent definition (architects, engineers, reviewers, testers, fls, scribes, second-opinion) and by the Director itself.

As established in ADR-0027, the protocol has 3 invocation modes:

| Mode | Steps | Purpose | Used By |
|------|-------|---------|---------|
| **Pre-task** | 1-2 (search learnings) | Load relevant context before executing | All teams before delegation |
| **Post-task** | 4-8 (reflect, consolidate, store, distill) | Store findings after execution | Scribes (per ADR-0018) |
| **Full** | 1-8 (all steps) | Search + execute + store | Teams working independently |

**Problem:** The skill uses ICM MCP tools (`icm_memory_store`, `icm_memory_recall`, `icm_memoir_search`, etc.) which are being deprecated per ADR-0029. All memory operations must migrate to agentmemory's MCP tools (`memory_save`, `memory_recall`, `memory_lesson_recall`, etc.).

Additional issues with the current skill:
1. ICM's `memoir` concept system has no direct agentmemory equivalent — learnings must be stored differently
2. The skill references `kodehold-learnings` and `kodehold-teams` memoirs which are ICM-specific concepts
3. The topic prefix convention (`kodehold-<project>-*`) must be replaced with agentmemory's `project` parameter (per ADR-0028, this is the full filesystem path)

### Key Forces

1. **Same modes, new tools.** The 3-mode structure (Pre-task/Post-task/Full) is well-tested and should be preserved. Only the underlying tools change.
2. **All agents must update.** Any agent that references "ICM Knowledge Flow" must be updated to "Agentmemory Knowledge Flow" simultaneously.
3. **Skill directory rename.** The physical directory must be renamed from `icm-knowledge-flow/` to `agentmemory-knowledge-flow/` to avoid confusion.
4. **Backward compatibility during transition.** During Phase 1 (dual-write), both skills could theoretically coexist. After Phase 2, only agentmemory-knowledge-flow exists.
5. **Topic convention migration.** ICM used topic prefixes (`kodehold-<project>-<type>`). Agentmemory uses the `project` parameter (full filesystem path per ADR-0028) plus structured `type` and `tags`.

### Prior Art

- **ADR-0027** (ICM Knowledge Flow Invocation Modes) — defined the 3-mode protocol being replaced
- **ADR-0029** (ICM → Agentmemory Migration Strategy) — established the overall migration approach; this ADR implements Phase 2
- **ADR-0028** (Agentmemory Project Detection) — established full filesystem path as canonical project name, which agentmemory knowledge flow uses
- **ADR-0018** (Scribes Centralization) — established that Scribes handles all post-task knowledge flow; this ADR preserves that delegation

## Decision

### Replace ICM Knowledge Flow with Agentmemory Knowledge Flow

1. **Rename skill directory:** `.opencode/skills/icm-knowledge-flow/` → `.opencode/skills/agentmemory-knowledge-flow/`
2. **Replace all ICM tool calls** with agentmemory equivalents in the 3-mode protocol
3. **Preserve the 3-mode structure** (Pre-task/Post-task/Full) — teams invoke the same way, get different behavior
4. **Update all 8 agent definitions** to reference "Agentmemory Knowledge Flow" instead of "ICM Knowledge Flow"
5. **Deprecate ADR-0027** — replaced by this ADR

### Agentmemory Knowledge Flow Protocol (3 Modes)

#### Pre-task (Context Loading)

Executed before delegation. Purpose: load relevant context into working memory.

| Step | Action | Agentmemory Tool | Role |
|------|--------|-----------------|------|
| 1 | Search shared learnings | `memory_lesson_recall(query="<topic>", project="<path>")` | Retrieve lessons from all teams |
| 2 | Search team-specific learnings | `memory_lesson_recall(query="<topic>", tags="team:<name>")` | Retrieve team-specific lessons |
| 3 | Recall recent relevant context | `memory_recall(query="<topic>", limit=5)` | Bring up recent memories |
| 4 | Cross-source search (optional) | `memory_smart_search(query="<topic>")` | Find across all memory types |

#### Post-task (Knowledge Storage)

Executed after delegation (delegated to Scribes per ADR-0018). Purpose: store findings, update lessons.

| Step | Action | Agentmemory Tool | Role |
|------|--------|-----------------|------|
| 1 | Store decision/memory | `memory_save(content, type, project, tags)` | Persistent record |
| 2 | Save lesson learned | `memory_lesson_save(content, confidence, tags)` | Teach other agents |
| 3 | Update action if active | `memory_action_update(id, status, result)` | Mark delegation complete |
| 4 | Consolidate if threshold met | `memory_consolidate(tier="episodic")` | Compress episodic→semantic |
| 5 | Extract patterns (periodic) | `memory_patterns(project="<path>")` | Detect recurring themes |

#### Full Mode (Standalone Work)

Executed when a team works without Director supervision. Combines Pre-task + Post-task.

| Step | Action | Agentmemory Tool |
|------|--------|-----------------|
| 1-4 | Pre-task steps | Same as Pre-task |
| 5 | Execute task (team workflow) | — |
| 6-10 | Post-task steps | Same as Post-task |

### Topic Convention Migration

| ICM Convention | Agentmemory Equivalent | Example |
|----------------|----------------------|---------|
| `topic="kodehold-architects-design"` | `project="/home/kiffer/project/kodehold"` + `type="design"` | Project scoping per ADR-0028 |
| `memoir="kodehold-learnings"` | `memory_lesson_recall()` with tags | Lessons are agentmemory's native concept |
| `memoir="kodehold-teams"` | `memory_lesson_recall(tags="team:<name>")` | Filter by team tag |
| Topic-based consolidation | `memory_consolidate(tier=...)` | Agentmemory auto-tiers |

### Tool Mapping (from SKILL.md)

| Current ICM Tool | Replacement Agentmemory Tool |
|-----------------|-----------------------------|
| `icm memoir search-all <query>` | `memory_lesson_recall(query=...)` or `memory_smart_search(query=...)` |
| `icm memoir search ... in kodehold-learnings` | `memory_lesson_recall(query=..., project="<path>")` |
| `icm memoir search ... in kodehold-teams` | `memory_lesson_recall(query=..., tags="team:...")` |
| `icm_memory_store topic=...` | `memory_save(content=..., project="<path>", type=..., tags=...)` |
| `icm_memory_recall -t <topic>` | `memory_recall(query=..., project="<path>")` |
| `icm_memory_consolidate` | `memory_consolidate(tier=...)` |
| `icm_memory_extract_patterns` | `memory_patterns(project="<path>")` |
| `icm_memoir_refine` | `memory_lesson_save(content=..., confidence=...)` |

### What This Changes

- **Skill directory:** Rename `icm-knowledge-flow/` → `agentmemory-knowledge-flow/`
- **Skill content:** All tool calls replaced. 8-step protocol restructured into 3-mode with explicit agentmemory tools.
- **Agent definitions (8):** Replace all "ICM Knowledge Flow" references with "Agentmemory Knowledge Flow"
- **ADR-0027:** Mark as Deprecated, cross-reference this ADR
- **All teams:** Must update their pre-task and post-task workflows

## Consequences

### Positive

1. **Native agentmemory operations.** All knowledge flow steps use agentmemory's native MCP tools. No ICM dependency.
2. **Better semantic search.** `memory_smart_search` and `memory_lesson_recall` provide hybrid semantic+keyword search, superior to ICM's FTS5-only search.
3. **Structured lesson storage.** Agentmemory's `memory_lesson_save/recall` replaces ICM's `memoir` system with explicit confidence scoring and tagging.
4. **Same modes, same workflow.** Teams don't need to learn a new process — just different tools behind the same 3-mode structure.
5. **Consolidation automated.** Agentmemory's `memory_consolidate` with tier parameter replaces ICM's manual consolidation.
6. **Pattern detection.** `memory_patterns` provides pattern detection that ICM lacked.

### Negative

1. **All 8 agent files must change simultaneously.** A partial update (e.g., updating architects but not engineers) would create a split state where some agents use agentmemory knowledge flow and others use ICM.
2. **Skill directory rename must be atomic.** If `icm-knowledge-flow/` is deleted before `agentmemory-knowledge-flow/` is created, agents lose their knowledge flow skill.
3. **Topic convention change.** Teams accustomed to ICM's `topic` parameter must adapt to agentmemory's `project` + `type` + `tags` model.
4. **No direct `memoir` equivalent.** ICM's memoir system (concept extraction, linking, inspection) has no perfect agentmemory equivalent. `memory_lesson_recall` covers most use cases, but `memory_verify` and `memory_facet_tag` handle linking differently.

### Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Agent confusion during transition** — some agents use old skill, some use new | Medium | High | All agent files updated in Phase 2 simultaneously. Only after ALL agents updated, delete old skill. |
| 2 | **Lessons lost** — `memory_lesson_save` has different schema than `icm_memoir_add_concept` | Low | Medium | Existing lessons remain in `.icm/` archive. New lessons use agentmemory's schema. |
| 3 | **Performance regression** — agentmemory may be slower than ICM for high-frequency operations | Low | Low | Agentmemory daemon is running locally; latency should be comparable. Benchmark after Phase 2. |
| 4 | **Scribes double burden** — must learn agentmemory knowledge flow while ICM is being decommissioned | Medium | Medium | Scribes is updated last so they can learn from migrated agents. |

### Follow-up Items

- [ ] Rename skill directory: `.opencode/skills/icm-knowledge-flow/` → `.opencode/skills/agentmemory-knowledge-flow/`
- [ ] Rewrite SKILL.md with agentmemory tools and 3-mode protocol
- [ ] Update all 8 agent definitions to reference "Agentmemory Knowledge Flow"
- [ ] Create `agentmemory-knowledge-flow/README.md` documenting the renamed skill
- [ ] Mark ADR-0027 as Deprecated
- [ ] Update `.opencode/skills/investigate/SKILL.md` — replace "Store findings in ICM" with agentmemory

### How to Revert

1. Restore the old `icm-knowledge-flow/` directory from git
2. Revert all 8 agent files to their pre-migration state
3. Reactivate ADR-0027 (ICM Knowledge Flow Invocation Modes)
4. This ADR becomes Deprecated

## ADR References

- **ADR-0027** (ICM Knowledge Flow Invocation Modes) — **Deprecated** by this ADR. Defined the 3-mode protocol that this ADR preserves but reimplements with agentmemory tools.
- **ADR-0028** (Agentmemory Project Detection) — established full filesystem path as project name, which this ADR uses for `project` parameter
- **ADR-0029** (ICM → Agentmemory Migration Strategy) — Phase 2 of the migration plan; this ADR implements that phase
- **ADR-0018** (Scribes Centralization) — Scribes continues to handle post-task knowledge flow; this ADR preserves that delegation
- **ADR-0031** (Actions + Crystals for Director Delegation) — downstream ADR that relies on agentmemory being the primary memory system
- **Impact analysis** Section 3 (Phase 2) — detailed file inventory for infrastructure migration

### Source Files Referenced

- `.opencode/skills/icm-knowledge-flow/SKILL.md` (skill to be renamed and rewritten)
- `.opencode/skills/investigate/SKILL.md` (3 ICM references to migrate)
- All `.opencode/agents/*.md` files (8 agents referencing ICM Knowledge Flow)
- `docs/adr/ADR-0027-icm-knowledge-flow-invocation-modes.md` (to be deprecated)
