# Version 0.15.0 — ADR-0027 ICM Knowledge Flow Invocation Modes

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.15.0 | 2026-05-29 | Registered ADR-0027 — ICM Knowledge Flow Invocation Modes (Proposed). Fixed consolidation threshold inconsistency (>5→>7) in ADR-0027. |
| 0.14.0 | 2026-05-29 | Dedicated second-opinion subagent with Google Gemma 3 12B via OpenRouter, OpenRouter provider configured, Director routes second opinions to dedicated subagent, Reviewers.md cleaned up. Fixes #12 |
| 0.13.4 | 2026-05-29 | ICM Knowledge Flow skill frontmatter fix: added YAML frontmatter so skill registers with OpenCode |
| 0.13.3 | 2026-05-29 | Shipping gate alignment: AGENTS.md and ship.sh now agree on step count (8 total: 1 manual + 7 automated). CHANGES.md check upgraded from warn to fail. |
| 0.13.2 | 2026-05-29 | Fixed FLS→Scribes protocol inconsistency: removed direct ICM storage from FLS workflow, now delegates through Director→Scribes per ADR-0010 |
| 0.13.1 | 2026-05-29 | Shipping gate alignment: AGENTS.md now correctly documents 8 steps (1 manual + 7 automated in ship.sh). CHANGES.md check in ship.sh upgraded from warn to fail. Team Meeting clarified as manual pre-requisite. |
| 0.13.0 | 2026-05-29 | Dependabot config added: weekly automated dependency updates for GitHub Actions and npm packages in `.opencode/` |
| 0.12.0 | 2026-05-29 | GitHub MCP server upgrade: replaced deprecated `@modelcontextprotocol/server-github` npm package with official `github/github-mcp-server` Go binary v1.1.2. Resolves intermittent auth failures. Closed issues #22 (stale test count) and #25 (GitHub MCP auth) |
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

**0.15.0** — ADR-0027: ICM Knowledge Flow Invocation Modes. Defines three invocation modes (Pre-task, Post-task, Full) for the ICM Knowledge Flow skill. Fixed consolidation threshold inconsistency in ADR-0027.

**0.14.0** — Dedicated second-opinion subagent with Google Gemma 3 12B via OpenRouter. OpenRouter configured as provider. Director routes second opinions to dedicated subagent. Reviewers.md cleaned up. Resolves issue #12 (bias problem).

**0.13.4** — ICM Knowledge Flow skill frontmatter fix. Added YAML frontmatter to `.opencode/skills/icm-knowledge-flow/SKILL.md` so the skill registers correctly with OpenCode's discovery.

**0.13.3** — Shipping gate alignment. AGENTS.md and ship.sh now agree on step count (8 total: 1 manual Team Meeting + 7 automated). CHANGES.md check upgraded from warn to fail. Team Meeting clarified as manual pre-requisite.

**0.13.2** — Fixed FLS ICM protocol inconsistency. Removed direct `icm_memory_store` call from FLS workflow. FLS now delegates ICM storage to Scribes via Director, consistent with ADR-0010 and director.md delegation patterns.

**0.13.1** — Shipping gate alignment. AGENTS.md now correctly documents 8 steps (1 manual + 7 automated in ship.sh). CHANGES.md check in ship.sh upgraded from warn to fail. Team Meeting clarified as manual pre-requisite.

**0.13.0** — Dependabot configuration added. `.github/dependabot.yml` enables weekly automated dependency updates for GitHub Actions (version + security) and npm packages in `.opencode/`.
