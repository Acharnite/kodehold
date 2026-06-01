---
name: agentmemory-knowledge-flow
description: |
  Shared Agentmemory Knowledge Flow used by all 6 team subagents.
  3 invocation modes: Pre-task, Post-task, Full.
  Triggers on delegation. Use at session start and after each delegation round.
---

# Agentmemory Knowledge Flow

## Invocation Modes

This skill has 3 modes based on when the team is invoked:

### Pre-task Mode (steps 1-2)
Run BEFORE starting work. For teams that execute tasks.

1. **Search shared learnings** — search `kodehold-learnings` for relevant patterns:
   ```
   agentmemory_memory_lesson_recall(query="[relevant keywords]", limit=5)
   ```
2. **Search team learnings** — search `kodehold-teams` for team-specific patterns:
   ```
   agentmemory_memory_lesson_recall(query="[relevant keywords]", limit=5)
   ```

### Post-task Mode (steps 4-8)
Run AFTER completing work. For all teams, and the ONLY mode for Scribes.

4. **Reflect** — identify what was learned: new patterns, issues found, insights gained
5. **Consolidate check** — if topic has excessive entries, consolidate:
   ```
   agentmemory_memory_diagnose()
   agentmemory_memory_consolidate(tier="episodic")
   ```
6. **Store shared learnings**:
   ```
   agentmemory_memory_save(
     content="[what was learned — cross-team patterns]",
     type="pattern",
     project="kodehold",
     concepts="learnings, [relevant keywords]"
   )
   ```
7. **Store team learnings**:
   ```
   agentmemory_memory_save(
     content="[what was learned]",
     type="pattern",
     project="<project-slug>",
     concepts="<team>-learnings, [relevant keywords]"
   )
   ```
8. **Refine concepts** — if a pattern has occurred 2+ times:
   ```
   agentmemory_memory_lesson_save(
     content="[refined definition based on new evidence]",
     tags=["recurring-pattern", "<concept-name>"]
   )
   ```

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

## Important Notes
- Steps 1-2 are SEARCH ONLY — no writes
- Step 4 is mental reflection — no tool calls
- Steps 5-8 are WRITE operations — use with care
- Step 3 (Execute task) is NOT part of knowledge flow — it is the team's own workflow
- The Director specifies which mode to use in delegation prompts
- Scribes never runs steps 1-2 (pre-task search)
