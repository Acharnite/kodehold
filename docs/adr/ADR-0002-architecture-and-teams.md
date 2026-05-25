# ADR-0002: Organizational Structure — Director and Teams

## Status

Accepted

## Context

KodeHold needs a team structure that mirrors a disciplined software organization. The structure must support:
- Clear role separation so no single agent is responsible for both creating and validating work
- A hierarchy that ensures quality gates are enforced
- Flexibility to add or remove teams without architectural changes
- Compatibility with OpenCode's agent system

## Decision

We adopt a Director + 5 specialist teams structure:

```
Director
├── Architects   — design authority, ADRs, technical decisions
├── Engineers    — implementation, refactoring, bug fixes
├── Reviewers    — code review, design review, standards enforcement
├── Testers      — test authoring, verification, regression
└── Scribes      — ICM memory, documentation, knowledge extraction
```

**Director**: Top-level orchestrator. Owns the project lifecycle (init → active → review → closed → reopen). Assigns work to teams, enforces quality gates at each transition, and manages token budgets. The Director does not write code or tests directly — it coordinates.

**Architects**: Author and maintain the design document. Write ADRs for significant decisions. Evaluate technology options. Review all design changes. Only team that can approve design document modifications.

**Engineers**: Generate code from design specifications. Refactor existing code. Fix bugs. Work is always assigned with a reference to the specific design document section being implemented.

**Reviewers**: Review all code and design changes before they are accepted. Verify compliance with design doc, coding standards, and ADR decisions. Coordinate second opinion requests with the Director.

**Testers**: Write unit, integration, and e2e tests. Execute regression suites. Report coverage gaps back to Engineers. Testing is independent from implementation.

**Scribes**: Handle all ICM interactions — storing memories, retrieving context, extracting concepts. Generate documentation, CHANGELOGs, and summaries. This team exists solely to manage persistent knowledge, freeing other teams from context management overhead.

## Consequences

- Positive: Clear responsibilities — no role ambiguity
- Positive: Built-in quality gates via separation of review from implementation
- Positive: Scribes ensure persistent memory is actually used (not just configured)
- Negative: More handoffs = more orchestration steps per task
- Negative: Director becomes a bottleneck if not implemented efficiently
- Neutral: Teams can be collapsed in "light" mode (see ADR-0005)
