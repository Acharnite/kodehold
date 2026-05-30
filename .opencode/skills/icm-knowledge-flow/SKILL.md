---
name: icm-knowledge-flow
description: |
  Shared ICM Knowledge Flow used by all 6 team subagents.
  3 invocation modes: Pre-task, Post-task, Full.
  Triggers on delegation. Use at session start and after each delegation round.
---

# ICM Knowledge Flow

## Invocation Modes

This skill has 3 modes based on when the team is invoked:

### Pre-task Mode (steps 1-2)
Run BEFORE starting work. For teams that execute tasks.

1. **Search shared learnings** — search `kodehold-learnings` memoir for relevant patterns
2. **Search team learnings** — search `kodehold-teams` memoir for team-specific patterns

### Post-task Mode (steps 4-8)
Run AFTER completing work. For all teams, and the ONLY mode for Scribes.

4. **Reflect** — identify what was learned: new patterns, issues found, insights gained
5. **Consolidate check** — if `kodehold-<project>-<topic>` has >7 entries, consolidate via `icm_memory_consolidate`
6. **Store shared learnings** — `icm_memory_store` to `kodehold-learnings`
7. **Store team learnings** — `icm_memory_store` to `kodehold-<project>-<topic>-<team>-learnings`
8. **Refine concepts** — `icm_memoir_refine` for recurring patterns (2+ occurrences)

### Full Mode (steps 1-2, 4-8)
Run both pre-task and post-task. Rare — when a team both searches and stores in one delegation.

## Mode Selection

| Team | Default Mode | Notes |
|------|-------------|-------|
| Engineers | Pre-task → (post-task via Director follow-up) | Director invokes post-task after completion |
| Testers | Pre-task → (post-task via Director follow-up) | Same as Engineers |
| Reviewers | Pre-task → (post-task via Director follow-up) | Same as Engineers |
| FLS | Pre-task → (post-task via Director follow-up) | Same as Engineers |
| Architects | Pre-task → (post-task via Director follow-up) | Same as Engineers |
| **Scribes** | **Post-task only** | Never runs pre-task search steps |
| (Rare/Explicit) | **Full** | When Director explicitly requests pre+post in one delegation |

## Step Details

### Step 1: Search shared learnings
```
icm_memoir_search(memoir="kodehold-learnings", query="[relevant keywords]")
```

### Step 2: Search team learnings
```
icm_memoir_search(memoir="kodehold-teams", query="[relevant keywords]")
```

### Step 4: Reflect
After executing the team's core task, identify:
- New patterns discovered
- Issues encountered and resolved
- Insights gained about the codebase, process, or tools
- Anti-patterns to avoid

### Step 5: Consolidate check
```
icm_memory_health(topic="kodehold-<project>-<topic>")
```
If entries >7, consolidate:
```
icm_memory_consolidate(topic="kodehold-<project>-<topic>", summary="[concise summary]")
```

### Step 6: Store shared learnings
```
icm_memory_store(
  topic="kodehold-learnings",
  content="[what was learned — cross-team patterns]",
  importance="[critical|high|medium|low]",
  keywords=["[relevant]", "[keywords]"]
)
```

### Step 7: Store team learnings
```
icm_memory_store(
  topic="kodehold-<project>-<topic>-<team>-learnings",
  content="[what was learned]",
  importance="[critical|high|medium|low]",
  keywords=["[relevant]", "[keywords]"]
)
```

### Step 8: Refine concepts
If a pattern has occurred 2+ times:
```
icm_memoir_refine(
  memoir="[memoir-name]",
  name="[concept-name]",
  definition="[refined definition based on new evidence]"
)
```

## Important Notes
- Steps 1-2 are SEARCH ONLY — no writes
- Step 4 is mental reflection — no tool calls
- Steps 5-8 are WRITE operations — use with care
- Step 3 (Execute task) is NOT part of knowledge flow — it is the team's own workflow
- The Director specifies which mode to use in delegation prompts
- Scribes never runs steps 1-2 (pre-task search) — this is the key change from ADR-0027
