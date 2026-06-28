---
name: agentmemory-knowledge-flow
description: DEPRECATED — replaced by opencode-rag-knowledge-flow. See ADR-0050.
---

# Agentmemory Knowledge Flow — DEPRECATED

> **This skill is deprecated.** It has been replaced by [opencode-rag-knowledge-flow](../opencode-rag-knowledge-flow/SKILL.md) per ADR-0050 (Agentmemory → OpenCode RAG Migration).
>
> The agentmemory daemon (`iii`) and REST API (port 3111) are being removed. Using this skill will eventually fail when the daemon is decommissioned.
>
> **Do not use in new work.** Migrate existing agent files to reference `opencode-rag-knowledge-flow` instead.

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

2. **Search team learnings** — broader search for team-specific patterns (fallback):
   ```
   agentmemory_memory_lesson_recall(
     query="<team-name> <relevant-keywords>",
     limit=10,
     project="kodehold"
   )
   ```

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
> **DEPRECATED.** This skill will be removed when agentmemory is decommissioned. Use `opencode-rag-knowledge-flow` instead.
