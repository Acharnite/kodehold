# graphify-knowledge-flow

Pre-task knowledge retrieval via Graphify knowledge graph queries.

## Pre-task Knowledge Retrieval

Before starting work, retrieve code context using Graphify:

1. **Query the knowledge graph** — for structural code understanding:
   ```
   graphify query "<question about code structure, dependencies, or symbols>"
   ```

2. **Query specific relationships**:
   ```
   graphify query "callers of <function-name>"
   graphify query "definition of <symbol>"
   graphify query "files that import <module>"
   graphify query "class hierarchy of <class-name>"
   ```

3. **Trace connections**:
   ```
   graphify path "<nodeA>" "<nodeB>"    # find shortest path between two concepts
   graphify explain "<node>"            # explain a node and its neighbors
   ```

4. **Search broader context** — for natural language questions:
   ```
   graphify query "<natural language question about architecture or behavior>"
   ```

5. **Search runtime context** — for cross-session learnings:
   ```
   search_memories(query="<topic>", scope="project")
   ```

## Fallback
- `grep` / `glob` for exact pattern matching
- `search_memories` for runtime context and prior learnings

Decision tree:
| Question type | Use |
|--------------|-----|
| "What does this function call?" | `graphify query "callers of <function>"` |
| "Where is this symbol defined?" | `graphify query "definition of <symbol>"` |
| "What imports this module?" | `graphify query "files importing <module>"` |
| "How does error handling work?" | `graphify query "error handling architecture"` |
| "Find something related to X" | `graphify query "X and its dependencies"` |
| "What did we learn about Y?" | `search_memories(query="Y", scope="project")` |
