# Version 0.11.0 — Documentation Audit & Issue Cleanup

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.11.0 | 2026-05-29 | Documentation audit: corrected test count (10→12), marked light mode complete, fixed version header consistency, updated README ADR range, closed stale GitHub issues #4 and #5 |
| 0.10.0 | 2026-05-29 | ADR status compliance fix (ADR-0015/0016/0019), gate.sh workspace `--project-path`, commit protection protocol, git clean -fd safeguard |
| 0.9.0 | 2026-05-27 | Gate markers (.design_reviewed, .impact_analysis_done), user review stop at INIT→ACTIVE, session checkpoint protocol, compaction config, Architects research, ADR-0014 dashboard |
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

**0.11.0** — Documentation audit and issue cleanup. Corrected test count from 10 to 12 (4 smoke + 3 init + 5 integration). Marked light mode implementation as complete (all 4 sub-items done). Fixed design doc version header consistency (was 1.4.8, changelog had 1.4.9). Updated README.md ADR range from 0011 to 0025. Closed stale GitHub issues #4 (GitHub integration) and #5 (ICM context summaries).
