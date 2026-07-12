---
name: opencode-rag-knowledge-flow
description: Pre-task knowledge retrieval for agents. Search the indexed codebase with search_semantic, find_usages, and get_file_skeleton before starting work.
---

# OpenCode RAG Knowledge Flow

> **MCP memory tools are available alongside RAG tools.** opencode-mem (`search_memories`, `add_memory`, etc.) provides persistent memory across sessions. Use RAG tools for code/doc retrieval; use memory tools for runtime learnings and session context. See ADR-0051 for details.

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

### Persistent Memory Recall

> **CRITICAL: Always pass `scope: "project"` to ALL memory tool calls.** KodeHold shares an opencode-mem instance with other agents (e.g., Bob). Without explicit project scoping, `search_memories` and `add_memory` will return/write memories from ALL projects. Every `search_memories` and `add_memory` call MUST include `scope: "project"` to prevent cross-project memory bleed.

opencode-mem MCP tools run **in parallel** with the RAG retrieval above. Use them to recall learnings, decisions, and session context that exist outside the codebase.

1. **Search stored memories** — query the memory store for prior learnings:
   ```
   search_memories(query="<topic>", scope="project")
   ```
   Use this when asking "what did we learn about X?" or "what happened last time we touched this?"

2. **Store learnings after work** — capture patterns, decisions, or fixes for future recall:
   ```
   add_memory(content="<learning or decision>", scope="project")
   ```
   Tag memories when possible (e.g., `"bugfix"`, `"pattern"`, `"decision"`) to make future retrieval more precise.

3. **When to use memory vs RAG:**

   | Question | Tool | Why |
   |----------|------|-----|
   | "What does this code do?" | `search_semantic` | Code is in the indexed workspace |
   | "What ADR covers this?" | `search_semantic` | ADRs are indexed files |
   | "What did we learn about this bug?" | `search_memories(scope="project")` | Learnings are stored as memories |
   | "What triage pattern applies here?" | `search_memories(scope="project")` | Patterns are runtime knowledge |
   | "What decision did we make last session?" | `search_memories(scope="project")` | Session context is in memory |
   | "Where is this function used?" | `find_usages` | Symbol references are in the index |

4. **Post-task memory capture** — after completing any work, store what you learned:
   ```
   add_memory(content="When fixing <bug>, the root cause was <X> and the solution was <Y>", scope="project")
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
- **Memory scoping is MANDATORY.** Every `search_memories` and `add_memory` call MUST include `scope: "project"`. This prevents memories from other projects (e.g., Bob) from appearing in KodeHold results. There are NO exceptions to this rule.
- RAG steps (1-5) are SEARCH ONLY — no writes. Memory steps (`add_memory`) are WRITE operations — use them after completing work, not during search phases.
- `search_semantic` searches the indexed workspace files — not a runtime database. New or heavily modified content may not appear immediately if the index is stale. Re-run the search after a brief delay if results seem incomplete.
- `search_memories` searches the opencode-mem memory store — runtime session context and agent learnings. It is independent of the codebase index.
- `find_usages` requires index freshness. After renaming or deleting symbols, the index may briefly return stale results.
- `get_file_skeleton` is MANDATORY before reading any file — it avoids token waste on irrelevant sections.
- RAG and memory are complementary: RAG for code/docs, memory for learnings/decisions. Use both in pre-task mode for full context.
- There is NO Post-task or Full mode for RAG. For memory, use `add_memory` post-task to capture what you learned. If you discover something worth preserving in the codebase, document it in the appropriate file (ADRs, design docs) — memory is for ephemeral learnings, files are for permanent decisions.
