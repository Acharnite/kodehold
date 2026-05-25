# Version 0.3.0 — Orchestrator Build

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.3.0 | 2026-05-26 | Director agent, lifecycle gates, workspace system, state-aware agents, proof-of-concept project |
| 0.2.0 | 2026-05-25 | Director orchestrator, 5 team subagents, test suite, CI, shipping gate |
| 0.1.0 | 2026-05-25 | Initial design documents and ADRs |

## Version Scheme

`MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to KodeHold methodology or architecture
- **MINOR**: New features, teams, or ADRs added
- **PATCH**: Documentation updates, refinements, bug fixes

## Current

**0.3.0** — Orchestrator build. Director as working agent with `task: allow`, lifecycle state tracking (`.kodehold-state`), automated gates (`scripts/gate.sh`) with 5 transitions, workspace management (`scripts/workspace.sh`) with project registry, second opinion protocol, centralized ICM, state-aware subagents with refusal/escalation protocol, Scribes documentation workflow. All validated against lib-validate project through full INIT→CLOSED lifecycle.
