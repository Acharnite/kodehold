---
name: agentmemory-knowledge-flow
description: Pre-task knowledge retrieval for agents. Search agentmemory for relevant patterns and team-specific learnings before starting work.
---

# Agentmemory Knowledge Flow

## Invocation Modes

This skill has 1 mode:

### Pre-task Mode (steps 1-2)
Run BEFORE starting work. For teams that execute tasks.

1. **Search shared learnings** — search for relevant patterns tagged for this team:
   ```
   agentmemory_memory_lesson_recall(
     query="<team-name> lessons patterns <relevant-keywords>",
     limit=10,
     project="kodehold"
   )
   ```
   Replace `<team-name>` with your team tag (e.g., `engineers`, `reviewers`, `testers`, `architects`, `fls`, `scribes`).
   > **Why two terms?** The term "lessons" helps bias the query toward structured lesson content, while "patterns" matches the pattern/extraction vocabulary used in the knowledge flow.

2. **Search team learnings** — broader search for team-specific patterns (fallback):
   ```
   agentmemory_memory_lesson_recall(
     query="<team-name> <relevant-keywords>",
     limit=10,
     project="kodehold"
   )
   ```
   Replace `<team-name>` with your team tag.
   > **Why the fallback?** If the first query with "lessons patterns" is too narrow, dropping those terms broadens the search without losing the team scope.

3. **Fallback** — if either query returns fewer than 3 results, re-query with broader terms:
    ```
    agentmemory_memory_lesson_recall(
      query="<team-name> lessons",
      limit=5,
      project="kodehold"
    )
    ```

4. **Recall relevant procedures** — search for workflow procedures relevant to your task:
   ```
   curl -s http://localhost:3111/agentmemory/procedural | python3 -c "
   import json, sys
   topic = '<relevant-keywords>'
   data = json.load(sys.stdin).get('procedural', [])
   matches = [p for p in data if topic in p.get('name', '').lower() or topic in p.get('triggerCondition', '').lower()]
   print(f'Found {len(matches)} relevant procedures')
   for p in matches[:3]:
       print(f\"  - {p['name']}\")
       print(f\"    Trigger: {p['triggerCondition']}\")
       print(f\"    Steps: {len(p.get('steps',[]))}\")
   "
   ```
   Replace `<relevant-keywords>` with relevant terms from your task. Skip this step if `curl` is not available.

## Mode Selection

| Team | Default Mode | Notes | Recall Query Prefix |
|------|-------------|-------|---------------------|
| Engineers | Pre-task | Search for relevant engineering patterns before starting work | `engineers` |
| Testers | Pre-task | Search for relevant testing patterns before starting work | `testers` |
| Reviewers | Pre-task | + Procedure recall | `reviewers` |
| FLS | Pre-task | Search for relevant hotfix patterns before starting work | `fls` |
| Architects | Pre-task | Search for relevant architectural patterns before starting work | `architects` |
| Scribes | N/A | No knowledge flow needed | — |

## Important Notes
- Steps 1-2 are SEARCH ONLY — no writes
- Step 3 (Execute task) is NOT part of knowledge flow — it is the team's own workflow
- Step 4 (Procedure recall) is optional — skip if the REST API is unavailable
