# ICM Knowledge Flow

**Status:** Accepted
**Implementation:** `.opencode/skills/icm-knowledge-flow/SKILL.md`
**Used by:** All 6 team subagents

---

## What Is ICM Knowledge Flow?

ICM Knowledge Flow is the standardized 8-step protocol that governs how every KodeHold team interacts with the Infinite Context Memory (ICM) system before, during, and after task execution. It ensures that knowledge is consistently searched, captured, and refined across all teams — building institutional memory that persists across sessions and projects.

The protocol is implemented as an OpenCode skill (`.opencode/skills/icm-knowledge-flow/SKILL.md`) and is loaded on-demand by each team agent at task time. Each team parameterizes the 8 steps with team-specific search queries, memoir names, and topic namespaces.

---

## The 8-Step Protocol

Steps 1-2 run **before** the task (load context). Step 3 **is** the task. Steps 4-8 run **after** the task (store learnings).

| Step | Name | When | Description |
|------|------|------|-------------|
| 1 | Search shared learnings | Before task | Search `kodehold-learnings` memoir for relevant cross-team patterns |
| 2 | Search team learnings | Before task | Search `<team>-learnings` memoir for team-specific patterns |
| 3 | Execute task | During | Perform the team's standard workflow (design, implement, test, review, etc.) |
| 4 | Reflect | After task | Identify what was learned: new patterns, issues found, insights gained |
| 5 | Pre-store consolidation check | After task | If target topic has >5 entries, consolidate first (ICM warns at >7) |
| 6 | Store shared learnings | After task | Save findings that benefit all teams in `kodehold-learnings` |
| 7 | Store team learnings | After task | Save team-specific findings in `<team>-learnings` |
| 8 | Distill/refine concepts | After task | Add or refine concepts in relevant memoirs based on what was learned |

### Step Details

**Step 1 — Search shared learnings**
Before starting any work, search the shared `kodehold-learnings` memoir for patterns relevant to the current task. This prevents repeating mistakes and builds on solutions other teams have already discovered.

**Step 2 — Search team learnings**
Search the team's own `<team>-learnings` memoir for patterns specific to the team's domain. This gives each team access to its accumulated domain expertise.

**Step 3 — Execute task**
Perform the team's standard workflow. This is the actual work — the knowledge flow bookends it with context loading and knowledge preservation.

**Step 4 — Reflect**
After completing the task, consciously identify what was learned. This includes: new patterns discovered, issues encountered, insights gained, and anything that would benefit future work.

**Step 5 — Pre-store consolidation check**
Before storing new memories, check if the target topic already has >5 entries. ICM warns at >7 entries per topic. If the topic is approaching this limit, consolidate existing entries first using `icm_memory_consolidate` to keep the memory store clean and searchable.

**Step 6 — Store shared learnings**
Save findings from this task that are relevant to all teams (cross-cutting concerns, general patterns, reusable solutions) in the `kodehold-learnings` shared memoir or topic.

**Step 7 — Store team learnings**
Save team-specific findings (domain expertise, team-specific patterns, tool-specific insights) in the team's own `<team>-learnings` topic.

**Step 8 — Distill/refine concepts**
Add new concepts or refine existing ones in relevant memoirs. This is the highest-level knowledge operation — turning raw memories into permanent, structured knowledge nodes in the memoir graph.

---

## Team-Specific Parameters

Each team loads the same skill but parameterizes it differently:

| Team | Shared Learnings Query | Team Memoir | Team Learnings Topic | Concept Memoirs |
|------|----------------------|-------------|---------------------|-----------------|
| **Architects** | `"design pattern OR architecture OR tech evaluation"` | `kodehold-architects` (query: `"design OR ADR OR decision"`) | `kodehold-architects-learnings` | `kodehold-arch`, `kodehold-architects`, `kodehold-learnings` |
| **Engineers** | `"implementation OR pattern OR library OR performance"` | `kodehold-engineers` (query: `"convention OR refactor OR build"`) | `kodehold-engineers-learnings` | `kodehold-engineers`, `kodehold-learnings` |
| **Testers** | `"test OR edge case OR regression OR coverage"` | `kodehold-testers` (query: `"test OR fixture OR framework OR assertion"`) | `kodehold-testers-learnings` | `kodehold-testers`, `kodehold-learnings` |
| **Reviewers** | `"review OR security OR quality OR bug pattern"` | `kodehold-reviewers` (query: `"review OR checklist OR second opinion"`) | `kodehold-reviewers-learnings` | `kodehold-reviewers`, `kodehold-learnings` |
| **Scribes** | `"documentation OR knowledge OR memory"` | `kodehold-scribes` (query: `"ICM OR memoir OR distill OR MCP"`) | `kodehold-scribes-learnings` | `kodehold-scribes`, `kodehold-learnings` |
| **FLS** | `"hotfix OR bug OR escalation OR pattern"` | `kodehold-fls` (query: `"fix OR triage OR project OR quirk"`) | `kodehold-fls-learnings` | `kodehold-fls`, `kodehold-learnings` |

### How Parameters Map to Steps

| Parameter | Used in Step | Purpose |
|-----------|-------------|---------|
| Shared learnings query | Step 1 | What to search in `kodehold-learnings` before starting work |
| Team memoir | Step 2, Step 8 | Where to search for team-specific patterns (Step 2) and where to store distilled concepts (Step 8) |
| Team learnings topic | Step 7 | Where to store team-specific findings after task completion |
| Concept memoirs | Step 8 | Which memoirs to add/refine concepts in |

---

## Integration with KodeHold Lifecycle

### Per-Phase Behavior

The knowledge flow runs on every task delegation, adapting to the current lifecycle phase:

| Phase | Step 3 (Task) | Steps 6-7 (Store) |
|-------|--------------|-------------------|
| **INIT** | Architects create design doc + ADRs | Store design decisions, technology choices |
| **ACTIVE** | Engineers implement, Testers test, Reviewers review | Store implementation patterns, test strategies, review findings |
| **REVIEW** | Final verification and team meeting | Store review results, test outcomes |
| **CLOSED** | Scribes final documentation | Store project summary, extract reusable concepts |
| **REOPEN** | Impact analysis, design updates | Store impact assessment, updated decisions |

### Relationship to ICM Operations

The knowledge flow uses ICM MCP tools for all storage and retrieval:

- **Steps 1-2 (Search):** `icm_memory_recall`, `icm_memoir_search`
- **Step 5 (Consolidate):** `icm_memory_consolidate`
- **Steps 6-7 (Store):** `icm_memory_store`
- **Step 8 (Distill):** `icm_memoir_add_concept`, `icm_memoir_refine`, `icm_memory_extract_patterns`

### Consolidation Policy

ICM warns when a topic accumulates >7 entries. The knowledge flow enforces proactive consolidation:

- **Step 5** checks entry count before storing
- At >5 entries: consolidate before adding new memories
- Use `icm_memory_consolidate` to merge related entries
- Use `icm_memory_extract_patterns` to detect recurring patterns and create memoir concepts

### Auto-Dedup

ICM's MCP server auto-deduplicates: if a new memory has >85% hybrid similarity to an existing one in the same topic, it updates instead of creating a duplicate. This means agents should be descriptive enough in their memory content that semantically different facts don't collide.

---

## Design Rationale

### Why 8 Steps?

The protocol was designed to close the loop between knowledge acquisition and knowledge preservation:

1. **Search before work** (Steps 1-2) prevents reinventing solutions and builds on past experience
2. **Execute** (Step 3) is the actual task — the knowledge flow wraps around it
3. **Reflect and store** (Steps 4-8) ensures every task contributes to institutional memory

Without this protocol, teams would repeatedly solve the same problems and lose valuable insights when sessions end.

### Why Separate Shared vs Team Learnings?

- **Shared learnings** (`kodehold-learnings`) capture cross-cutting patterns useful to all teams (e.g., "ICM auto-dedup means we don't need manual deduplication")
- **Team learnings** (`<team>-learnings`) capture domain-specific expertise (e.g., "Engineers: RTK compact output reduces tokens 40-60%")

This separation keeps the shared space clean while giving each team deep domain memory.

### Why Distill Concepts (Step 8)?

Raw memories decay over time (especially Medium/Low importance). Concepts in memoirs never decay — they are permanent knowledge nodes that get refined over time. Step 8 ensures that the most valuable insights from tasks are elevated from ephemeral memories to permanent knowledge.

---

## Usage Example

When the Director delegates a task to Engineers:

```
Director → Task tool (engineers):
  Context: Implement authentication module per design doc section 4.
  Task: Implement login, logout, session management.
  Deliverables: Working auth module with passing tests
```

Engineers then run the knowledge flow:

1. **Search shared:** `icm_memoir_search "kodehold-learnings" "authentication OR session OR login"`
2. **Search team:** `icm_memoir_search "kodehold-engineers" "convention OR refactor OR build"`
3. **Execute:** Implement the authentication module
4. **Reflect:** "Discovered that session tokens should use JWT with 24h expiry. Found a pattern for refresh token rotation."
5. **Consolidate check:** `kodehold-engineers-learnings` has 4 entries — safe to add
6. **Store shared:** Store "JWT + refresh token rotation is the standard auth pattern" in `kodehold-learnings`
7. **Store team:** Store "Session token expiry convention: 24h access, 30d refresh" in `kodehold-engineers-learnings`
8. **Distill:** Add/refine `authentication` concept in `kodehold-engineers` memoir

---

## References

| Document | Path |
|----------|------|
| Skill implementation | `.opencode/skills/icm-knowledge-flow/SKILL.md` |
| ICM integration (design doc) | `docs/design/README.md` — Section 7.2 |
| ICM MCP Integration (ADR) | `docs/adr/ADR-0009-icm-mcp-integration.md` |
| Knowledge Extraction (ADR) | `docs/adr/ADR-0004-icm-rtk-integration.md` |
| Agent definitions | `.opencode/agents/{architects,engineers,testers,reviewers,scribes,fls}.md` |
