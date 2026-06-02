# Version 0.19.2 — ADR-0036 Project Slug Convention

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.19.2 | 2026-06-02 | ADR-0036 slug convention, custom viewer server, Slots tab, Director protocol slug update, workspace validation |
| 0.19.1 | 2026-06-02 | CI fixes: ADR format test SIGPIPE antipatch resolved, agentmemory health check warns (not fails) in CI, obsolete ICM setup steps removed from CI workflow. |
| 0.18.0 | 2026-06-01 | Token report tool (`scripts/token-report.py`): self-contained HTML report at `docs/dashboard/index.html` with cost/token charts, per-model/per-team/per-provider tables, OpenRouter billing integration. 5 chart types (daily cost trend, daily tokens, cost by provider/model/team), dark-themed responsive UI. |
| 0.17.1 | 2026-06-01 | CodeRabbitAI review fix: added runtime validation for `info?.directory` in agentmemory-capture.ts (replaces type assertion with `typeof` + length check per PR #749). ADR-0028 updated with finalized date and validation details. |
| 0.17.0 | 2026-05-30 | ICM memoir restructure: 7 team memoirs merged into `kodehold-teams` (27 concepts, 16 links), learnings consolidated into `kodehold-learnings` (63 concepts, 68 links). All ADR/doc references updated. CLOSED→REOPEN→ACTIVE lifecycle transition. |
| 0.16.0 | 2026-05-29 | ADR-0021 accepted (Prospective Memory design), lifecycle simulation document (4 scenarios), ADR cleanup (5 ADRs resolved: Superseded/Deprecated), delegation lesson documented, OPENCODE_NONINTERACTIVE env leak test fix. |
| 0.15.2 | 2026-05-29 | ADR-0027 implementation review fixes: SKILL.md renumbered, docs updated, second-opinion.md standardized, typo fixed, Full mode added. |
| 0.15.1 | 2026-05-29 | Updated all 6 agent files with ADR-0027 invocation modes (Pre-task/Post-task). Scribes uses Post-task only; other teams use Pre-task default. |
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

**0.19.2** — Project slug convention (ADR-0036): project identifiers migrated from filesystem paths to stable slugs across Director protocol, workspace scripts, and design docs. New custom KodeHold viewer server (`tools/viewer/serve.mjs`, port 3115) with Slots tab. Director protocol updated to use stable slug `project` field. Workspace scripts validate project names as slugs; catalog uses `project: name` field.

**0.19.1** — CI stability fixes: ADR format smoke test SIGPIPE antipatch resolved (direct `grep -q` instead of piped `echo`), agentmemory health check warns instead of failing when daemon unreachable (three-way logic: connection refused → WARN, 2xx → PASS, 4xx/5xx → FAIL), obsolete ICM setup steps removed from CI workflow.

**0.19.0** — ICM → Agentmemory Migration (Phases 1-5). Complete replacement of ICM memory system with agentmemory. New ADR-0030 (Knowledge Flow), ADR-0031 (Actions + Crystals), ADR-0032 (Routine Templates), ADR-0033 (Crystals + Signals). Director now uses Action Frontier Protocol with memory_frontier + memory_lease + memory_crystallize. 4 standard flow templates (ADR, implement, bugfix, ship-gate). Auto-crystallize triggers (every 5 actions, state transitions, routine completion, explicit). Inter-agent signaling (5 types). All 6 team agents, scripts/gate.sh, scripts/ship.sh, references updated.

**0.17.1** — CodeRabbitAI review fix: added runtime validation for `info?.directory` in agentmemory-capture.ts. Replaces `(info?.directory as string)` type assertion with `typeof` + length check per PR #749. ADR-0028 updated with finalized date (2026-06-01) and validation documentation.

**0.17.0** — ICM memoir restructure: 7 team-specific memoirs merged into `kodehold-teams` (27 concepts, 16 links). All learnings consolidated into `kodehold-learnings` (63 concepts, 68 links). All ADR references updated to reflect new consolidated structure. CLOSED→REOPEN→ACTIVE lifecycle transition completed.

**0.16.0** — ADR-0021 accepted (Prospective Memory design for deferred + recurring tasks via ICM). Lifecycle simulation document with 4 complete scenarios. ADR cleanup: 5 ADRs resolved (Superseded/Deprecated). Director delegation lesson documented. OPENCODE_NONINTERACTIVE env leak test fix.

**0.15.2** — ADR-0027 implementation review fixes. SKILL.md renumbered to match ADR-0027, docs updated with invocation modes, second-opinion.md standardized, typo fixed.

**0.15.1** — Updated all 6 agent files with ADR-0027 invocation modes. Scribes uses Post-task only; other teams use Pre-task default. Fixes token waste and semantic confusion.

**0.14.0** — Dedicated second-opinion subagent with Google Gemma 3 12B via OpenRouter. OpenRouter configured as provider. Director routes second opinions to dedicated subagent. Reviewers.md cleaned up. Resolves issue #12 (bias problem).

**0.13.4** — ICM Knowledge Flow skill frontmatter fix. Added YAML frontmatter to `.opencode/skills/icm-knowledge-flow/SKILL.md` so the skill registers correctly with OpenCode's discovery.

**0.13.3** — Shipping gate alignment. AGENTS.md and ship.sh now agree on step count (8 total: 1 manual Team Meeting + 7 automated). CHANGES.md check upgraded from warn to fail. Team Meeting clarified as manual pre-requisite.

**0.13.2** — Fixed FLS ICM protocol inconsistency. Removed direct `icm_memory_store` call from FLS workflow. FLS now delegates ICM storage to Scribes via Director, consistent with ADR-0010 and director.md delegation patterns.

**0.13.1** — Shipping gate alignment. AGENTS.md now correctly documents 8 steps (1 manual + 7 automated in ship.sh). CHANGES.md check in ship.sh upgraded from warn to fail. Team Meeting clarified as manual pre-requisite.

**0.13.0** — Dependabot configuration added. `.github/dependabot.yml` enables weekly automated dependency updates for GitHub Actions (version + security) and npm packages in `.opencode/`.
