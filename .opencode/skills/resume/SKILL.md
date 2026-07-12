---
name: resume
description: |
  Resume an interrupted opencode session by loading the last session checkpoint from `.opencode/memory/checkpoints/`.
  Use when the user says "/resume", "resume session", "continue where I left off",
  or when context has overflowed and a fresh session is needed.
---

# Resume — Recover Interrupted Session

## Overview

When opencode context overflows or the session crashes, this skill reconstructs
the previous session's state from file-based checkpoints so work can continue seamlessly.

---

## Protocol

### Step 1: Determine project

Auto-detect project from the working directory, or accept an optional project path argument.

```bash
project=$(basename "$PWD")
```

### Step 2: Find latest checkpoint

List checkpoint files and find the most recent one for this project:

```bash
ls -t .opencode/memory/checkpoints/*.md 2>/dev/null | head -3
```

If no checkpoints exist, try finding any `.opencode/memory/` content:

```bash
ls .opencode/memory/checkpoints/ 2>/dev/null || echo "No checkpoints found"
```

### Step 3: Read the latest checkpoint

```bash
cat $(ls -t .opencode/memory/checkpoints/*.md 2>/dev/null | head -1)
```

### Step 4: Search for additional context

```bash
search_semantic(query="<project> session summary", topK=5)
```

### Step 5: Check current gate/state

```bash
bash scripts/gate.sh --status 2>/dev/null || echo "STATE: unknown"
```

### Step 6: Present structured summary to user

Format the output as follows:

```
## Session Resume — <project>

**State:** <gate state>

### Last Session Summary
- <content from latest checkpoint>

### Additional Context
- <results from search_semantic>
```

## Important Notes

1. All queries use `search_semantic` and file reads — no external daemon needed.
2. If no checkpoint file is found, report that clearly and suggest starting fresh.
3. Handle failures gracefully — if the checkpoint directory is empty, tell the user.
4. This skill loads the AI with context — it does NOT automatically execute anything.
5. The AI reads this skill, runs the steps, and presents the result to the user.

## Error Handling

| Scenario | Response |
|----------|----------|
| No checkpoint directory | "No checkpoints found. Start a fresh session manually." |
| Checkpoint exists but empty | "Checkpoint found but appears empty. Starting fresh." |
| search_semantic fails | "Could not load additional context. Starting with checkpoint data only." |
