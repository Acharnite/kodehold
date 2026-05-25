# ADR-0008: Project Lifecycle and Reopening

## Status

Accepted

## Context

KodeHold projects have a lifecycle: they are initiated, developed, reviewed, and closed. But software is never truly finished — bugs are discovered, new features are requested, dependencies need updating. A project must be reopenable months or years after closure with full context restored.

Without a defined lifecycle and reopening protocol:
- Closed projects accumulate "we'll fix it later" debt
- Reopening requires manual context reconstruction
- Design documents drift from the actual codebase over time

## Decision

### Project States

```
                  ┌──────────────────────────────────┐
                  │            INIT                   │
                  │  Design doc created               │
                  │  ADRs drafted                     │
                  │  Scope defined                    │
                  └──────────┬───────────────────────┘
                             │ Director approves
                             ▼
                  ┌──────────────────────────────────┐
                  │           ACTIVE                   │
                  │  Implementation in progress        │
                  │  Design doc updates via review      │
                  │  Continuous testing                 │
                  └──────────┬───────────────────────┘
                             │ All work complete
                             ▼
                  ┌──────────────────────────────────┐
                  │           REVIEW                   │
                  │  Final review by Reviewers         │
                  │  Full test suite run by Testers    │
                  │  Design doc verification            │
                  └──────────┬───────────────────────┘
                             │ Director closes
                             ▼
                  ┌──────────────────────────────────┐
                  │           CLOSED                   │
                  │  Context stored in ICM             │
                  │  Design doc archived               │
                  │  Project inactive                   │
                  └──────────┬───────────────────────┘
                             │ New feature / bugfix
                             ▼
                  ┌──────────────────────────────────┐
                  │           REOPEN                   │
                  │  Context loaded from ICM            │
                  │  Impact analysis (Architects)       │
                  │  Design doc updated                  │
                  └──────────┬───────────────────────┘
                             │ → ACTIVE (above)
```

### Close Protocol

When a project is closed, the Director orchestrates:

1. **Testers**: Run complete test suite. All tests must pass.
2. **Reviewers**: Final code review. Verify design doc matches implementation.
3. **Architects**: Final ADR review. Any decisions made during implementation that lack ADRs must be documented.
4. **Scribes**:
   - Store full project summary in ICM (memories with high importance)
   - Extract concepts for cross-project knowledge
   - Store design doc and ADR index as permanent memories
   - Log project status, dates, and team composition

### Reopen Protocol

When a project is reopened:

1. **Director**: Receives request with new requirements (features or bugfixes)
2. **Scribes**: Query ICM for all project memories. Load design doc, ADRs, and final context. Summarize for teams.
3. **Architects**: Perform impact analysis. Update design doc with new requirements. Write new ADRs for significant changes.
4. **Reviewers**: Review updated design doc and new ADRs.
5. **Director**: Transition to ACTIVE state. Assign implementation work to Engineers.

### Conditions for Reopening

- Bug fixes: Any project can be reopened for bug fixes regardless of age
- New features: Only if the design doc can accommodate them without requiring a full rewrite. If > 50% of the design would change, a new project should be created instead.
- Dependency updates: Can be handled as a bug fix (security) or new feature (major version bump)

### Archive

After 12 months in CLOSED state without reopening:
- Scribes archive low-level memories (keep only high-importance summaries)
- Full project code remains in git but ICM stores only essential context
- Reopening an archived project requires a full context rebuild (design doc re-review)

## Consequences

- Positive: Long-running projects maintain full context across months or years
- Positive: ICM stores project history for post-mortem analysis and training
- Positive: Reopen protocol ensures consistent process regardless of who initiates
- Negative: Archiving after 12 months means some context loss for very old projects
- Negative: Reopening requires the same teams to be available (may not be possible if team composition changed)
- Neutral: Projects that require >50% redesign are treated as new — prevents scope creep
