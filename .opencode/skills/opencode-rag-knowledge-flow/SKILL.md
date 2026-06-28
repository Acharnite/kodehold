---
name: opencode-rag-knowledge-flow
description: Pre-task knowledge retrieval for agents. Search the indexed codebase with search_semantic, find_usages, and get_file_skeleton before starting work.
---

# OpenCode RAG Knowledge Flow

## Invocation Modes

This skill has 1 mode:

### Pre-task Mode
Run BEFORE starting work. For all teams that execute tasks.

1. **Search relevant code and docs** — search the indexed codebase for patterns, designs, and documentation relevant to your task:
   ```
   search_semantic(
     query="<team-name> <task-keywords>",
     topK=5
   )
   ```
   Replace `<team-name>` with your team tag (e.g., `engineers`, `reviewers`, `testers`, `architects`, `fls`, `scribes`).
   Replace `<task-keywords>` with terms specific to your task.

   > **Why include the team name?** It biases results toward patterns, constraints, and decisions relevant to that team's domain (e.g., `engineers` finds implementation patterns, `reviewers` finds review checklist items).

2. **Search relevant documentation** — scope to docs and ADRs when looking for design decisions:
   ```
   search_semantic(
     query="<topic> design decisions",
     pathHints=["docs/"],
     topK=5
   )
   ```
   Use `pathHints` to limit searches to specific directories when you need authoritative design context rather than code-level patterns.

3. **Find symbol usages** — before editing any function, variable, or class, locate all references:
   ```
   find_usages(symbolName="<function-or-variable-name>")
   ```
   This is REQUIRED before editing any existing symbol — skipping this breaks unseen call sites.

4. **Understand file structure** — before reading any file, get its structural overview:
   ```
   get_file_skeleton(filePath="<path-to-file>")
   ```
   This is REQUIRED before reading any file — reading without this wastes tokens on irrelevant sections.

5. **Fallback with broader terms** — if the initial search returns fewer than 3 relevant results, re-query with broader terms:
   ```
   search_semantic(
     query="<team-name> <broader-keywords>",
     topK=5
   )
   ```

## Mode Selection

| Team | Default Mode | Notes | Search Prefix |
|------|-------------|-------|---------------|
| Engineers | Pre-task | Search for relevant engineering patterns before starting work | `engineers` |
| Testers | Pre-task | Search for relevant testing patterns before starting work | `testers` |
| Reviewers | Pre-task | Search for review checklists and standards | `reviewers` |
| FLS | Pre-task | Search for relevant hotfix patterns before starting work | `fls` |
| Architects | Pre-task | Search for relevant architectural patterns and ADRs before starting work | `architects` |
| Scribes | N/A | No knowledge flow needed | — |

## Important Notes
- Steps 1-2 are SEARCH ONLY — no writes.
- `search_semantic` searches the indexed workspace files — not a runtime database. New or heavily modified content may not appear immediately if the index is stale. Re-run the search after a brief delay if results seem incomplete.
- `find_usages` requires index freshness. After renaming or deleting symbols, the index may briefly return stale results.
- `get_file_skeleton` is MANDATORY before reading any file — it avoids token waste on irrelevant sections.
- There is NO Post-task or Full mode. Knowledge is stored directly in files (ADRs, design docs, agent files, skill files). If you discover something worth preserving, document it in the appropriate file — do not rely on external memory.
