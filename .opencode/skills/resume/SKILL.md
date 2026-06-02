---
name: resume
description: |
  Resume an interrupted opencode session by loading the last session context from agentmemory.
  Use when the user says "/resume", "resume session", "continue where I left off",
  or when context has overflowed and a fresh session is needed.
  Loads via agentmemory REST API (port 3111) directly — does NOT depend on MCP tools.
---

# Resume — Recover Interrupted Session

## Overview

When opencode context overflows or the session crashes, this skill reconstructs
the previous session's state from agentmemory so work can continue seamlessly.

All queries use **bash + curl** against the agentmemory REST API (`localhost:3111`)
directly, NOT the agentmemory MCP tools. This ensures the skill works even when
the MCP connection is broken (e.g., agentmemory server was killed mid-session).

---

## Protocol

### Step 1: Determine project

Auto-detect project from `process.cwd()`, or accept an optional project path argument.

```bash
project=$(basename "$PWD")
```

### Step 2: Query agentmemory REST API for latest session

Use curl to find the most recent session for the current project:

```bash
curl -s 'http://localhost:3111/agentmemory/sessions' | python3 -c "
import json, sys
data = json.load(sys.stdin)
sessions = [s for s in data.get('sessions', [])
            if s.get('project','').endswith('$project')
            and s.get('status') in ('active', 'completed')]
if not sessions:
    print('NO_SESSION')
    sys.exit(0)
latest = max(sessions, key=lambda s: s.get('startedAt',''))
print(json.dumps(latest, indent=2))
"
```

Save the **session ID**, **firstPrompt/summary**, and **startedAt** from the output.

### Step 3: Load observations from that session

```bash
curl -s "http://localhost:3111/agentmemory/observations?sessionId=$SESSION_ID&limit=20" | python3 -c "
import json, sys
data = json.load(sys.stdin)
observations = data.get('observations', data.get('items', []))
for obs in observations:
    title = obs.get('title', obs.get('narrative', ''))[:120]
    concepts = obs.get('concepts', [])
    files = obs.get('files', [])
    confidence = obs.get('confidence', 'N/A')
    print(f'  - {title}')
    if concepts: print(f'    concepts: {concepts}')
    if files: print(f'    files: {files}')
    print(f'    confidence: {confidence}')
"
```

Extract: titles, narratives, concepts, files touched, confidence scores.

### Step 4: Check for session checkpoint memories

```bash
curl -s 'http://localhost:3111/agentmemory/memories?query=checkpoint+session-summary&limit=10' | python3 -c "
import json, sys
data = json.load(sys.stdin)
memories = data.get('memories', [])
if not memories:
    print('No checkpoint found')
else:
    for m in memories[:3]:
        print(f'  - {m.get(\"content\",\"\")[:300]}')
        concepts = m.get('concepts', [])
        if concepts: print(f'    concepts: {concepts}')
"
```

### Step 5: Check current gate/state

```bash
bash scripts/gate.sh --status 2>/dev/null || echo "STATE: unknown"
```

### Step 6: Present structured summary to user

Format the output as follows:

```
## Session Resume — <project>

**Previous session:** <firstPrompt or summary>
**Started:** <startedAt>
**Status:** <active/completed>
**State:** <gate state>

### Recent Activity
- <observation titles/concepts>

### Files Touched
- <files from observations>

### Checkpoint
- <checkpoint content if found, or "No checkpoint found">

### Action Items
- Based on session context, suggest next steps:
  1. <suggestion based on firstPrompt>
  2. <suggestion based on summary>
  3. Suggest checking frontier via `agentmemory_memory_frontier()`
```

---

## Important Notes

1. **ALL queries** go through `curl http://localhost:3111/agentmemory/...` — NEVER use
   agentmemory MCP tools in this skill. The whole point is resilience when MCP is down.
2. If no session is found for the project, report that clearly and suggest starting fresh.
3. If observations are empty or limited, still present what IS available (at minimum the
   session metadata).
4. Handle failures gracefully — if agentmemory REST API is unreachable (`curl` fails or
   returns empty), tell the user and suggest manual recovery.
5. `python3` is used for JSON processing inline with the `-c` flag.
6. This skill loads the AI with context — it does NOT automatically execute anything.
   The AI reads this skill, runs the steps, and presents the result to the user.

## Error Handling

| Scenario | Response |
|----------|----------|
| curl fails / connection refused | "Agentmemory REST API unreachable at localhost:3111. Start a fresh session manually." |
| No sessions found for project | "No previous session found for `<project>`. Starting fresh." |
| Session found but no observations | Present session metadata, note no observations, suggest checking agentmemory directly. |
| Observations limited (< 3 entries) | Present what IS available and note the session was short-lived. |
