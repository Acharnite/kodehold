# Version 0.6.0 — Gate Enforcement and Design Doc Discipline

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.8.0 | 2026-05-27 | FLS-specific tests, shared .venv, English-only subagent prompts, ADR-0013 investigate skill, workspace `find` fix |
| 0.7.0 | 2026-05-27 | Investigate skill (gstack port), state-awareness skillified, per-project .icm/ removed, Test→Review gate enforced |
| 0.6.0 | 2026-05-27 | ACTIVE→REVIEW gate enforces Test→Review sequence, design doc discipline across all 7 agents, pytest best practices codified |
| 0.5.0 | 2026-05-27 | ICM docs study, auto-dedup/recall/extract_patterns tested, consolidation threshold in all agents, FLS cross-project recall + project discovery |
| 0.4.0 | 2026-05-27 | FLS, Team Meeting, Director default, ICM naming convention, cross-provider second opinion |
| 0.3.0 | 2026-05-26 | Director agent, lifecycle gates, workspace system, state-aware agents, proof-of-concept project |
| 0.2.0 | 2026-05-25 | Director orchestrator, 5 team subagents, test suite, CI, shipping gate |
| 0.1.0 | 2026-05-25 | Initial design documents and ADRs |

## Version Scheme

`MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes to KodeHold methodology or architecture
- **MINOR**: New features, teams, or ADRs added
- **PATCH**: Documentation updates, refinements, bug fixes

## Current

**0.8.0** — FLS-specific tests, shared .venv, English-only subagent prompts. New `tests/integration/04-fls-workflow.sh` with 50+ assertions across 7 areas. KodeHold root `.venv/` with pytest/pyyaml/requests — agents reference it consistently. Director Core Protocol rule #6 enforces English-only delegation prompts. ADR-0013 documents investigate skill architecture. Workspace `find` call removed (wasteful through symlinks).
