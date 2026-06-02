---
name: agentmemory-knowledge-flow
description: Pre-task knowledge retrieval for agents. Search agentmemory for relevant patterns and team-specific learnings before starting work.
---

# Agentmemory Knowledge Flow

## Invocation Modes

This skill has 1 mode:

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

## Mode Selection

| Team | Default Mode | Notes |
|------|-------------|-------|
| Engineers | Pre-task | Search for relevant engineering patterns before starting work |
| Testers | Pre-task | Search for relevant testing patterns before starting work |
| Reviewers | Pre-task | Search for relevant review patterns before starting work |
| FLS | Pre-task | Search for relevant hotfix patterns before starting work |
| Architects | Pre-task | Search for relevant architectural patterns before starting work |
| Scribes | N/A | No knowledge flow needed |

## Important Notes
- Steps 1-2 are SEARCH ONLY — no writes
- Step 3 (Execute task) is NOT part of knowledge flow — it is the team's own workflow
