# Changelog

## 0.6.0 — 2026-05-27

### Added
- ACTIVE→REVIEW gate enforces Test→Review sequence — checks `.testers_done` marker, blocks if missing
- Design doc discipline — all 7 agents now update the design doc after completing work
- Pytest best practices codified in Testers agent (`.venv/bin/pytest`, `PYTHONPATH=src`, `pytest-asyncio`, no `rtk pytest`)
- Pytest learning stored in ICM `kodehold-learnings` (high importance)

### Changed
- `scripts/gate.sh` — `active_to_review()` checks `.testers_done` marker, deletes after pass
- `.opencode/agents/testers.md` — creates `.testers_done` marker on completion, updates Testing Strategy section
- `.opencode/agents/reviewers.md` — refuses to start without `.testers_done`, updates design doc after review
- `.opencode/agents/engineers.md` — updates Component Design and Implementation Plan after implementation
- `.opencode/agents/architects.md` — reviews + updates design doc after implementation cycles
- `.opencode/agents/fls.md` — updates design doc if fix changes documented behavior
- `.opencode/agents/scribes.md` — updates design doc Changelog and Version in pre-transition workflow
- `.opencode/agents/director.md` — verifies design doc is updated before any gate transition
- All 7 agents — "update design doc after work" steps added to workflows

### Fixed
- Gate enforcement gap — parallel Test/Review no longer possible (`.testers_done` blocks at gate level)
- `VERSION.md`, `CHANGES.md`, `TODO.md` — bumped to 0.6.0

## 0.5.0 — 2026-05-27

### Added
- ICM docs study — architecture, features, guide, integrations, product read. Key insights stored in kodehold-learnings
- Consolidation threshold awareness — step 4 in ICM Knowledge Flow for all 6 agents: pre-store check at >5 entries
- FLS cross-project recall — searches project-specific topics (`kodehold-<project>`, `kodehold-<project>-fls`) when project name is known
- FLS project discovery — lists workspaces, all topics, and does broad ICM/memoir search when project name is forgotten
- `ICM-Docs-Best-Practices` concept in `kodehold-scribes` memoir

### Changed
- `scribes.md` — ICM Best Practices section (consolidation, store nudge, auto-dedup, pattern extraction, memory lifecycle)
- `director.md` — ICM Protocol extended with consolidate/extract patterns guidance
- `fls.md` — project discovery step before triage, project history recall in minor fix workflow
- All 6 agent files — ICM Knowledge Flow renumbered, step 4 added for pre-store consolidation check
- `VERSION.md` — bumped to 0.5.0
- `TODO.md` — marked 5 items completed, added 3 new items

### Tested
- **Auto-dedup** — identical memory in same topic → same ID (updated). Different memory → new ID.
- **Recall quality** — "authorization" returned 3 relevant results via hybrid search where FTS5 would give 0.
- **Extract patterns** — detected pattern across 2 session-checkpoint memories, created concept in kodehold-learnings.

## 0.4.0 — 2026-05-27

### Added
- FLS (Front Line Support) team — 6th team with triage, hotfix, and escalation protocol
- ADR-0010 — FLS Front Line Support Team (Accepted)
- ADR-0011 — Team Meeting (collective project review, replaces solo Director approval)
- `.opencode/agents/fls.md` — FLS agent definition with triage criteria and workflow
- Team Meeting as step 0 in shipping gate (9 steps total)
- Director as default_agent in opencode.json with mode: primary
- Second opinion now requires cross-provider model (Claude/Codex), not same-family local
- 7 new ICM memoirs: kodehold-architects, kodehold-engineers, kodehold-reviewers, kodehold-testers, kodehold-scribes, kodehold-fls, kodehold-learnings
- ICM Knowledge Flow (6-step) added to all 6 agent files: search shared → search team → execute → store shared → store team → distill/refine

### Changed
- ADR-0002 — Director + 5 teams → Director + 6 teams (FLS added)
- ADR-0003 — Final Review updated to Team Meeting (ADR-0011)
- ADR-0006 — second opinion must use different provider (cross-provider mandated)
- ADR-0008 — FLS triage gateway between CLOSED and REOPEN; Team Meeting in Close Protocol
- ADR-0009 — Status promoted from Proposed to Accepted
- All 6 agent files — ICM Knowledge Flow section added before existing workflows
- Scribes — migrated from CLI (`icm store`/`icm recall`) to MCP tools (`icm_memory_store`/`icm_memory_recall`)
- Reviewers — second opinion stores outcomes in team learnings
- Design doc — organisational structure (6 teams), Review Cadence, REVIEW state, ADR index
- README.md — architecture diagram includes FLS, 6 teams, ADR range to 0011
- VERSION.md — bumped to 0.4.0
- TODO.md — updated with all completed items

### Fixed
- All 11 ADRs now pass Nygaard format smoke test
- `teams` memoir: FLS concept added, kodehold concept updated to 6 teams, scribes refined to MCP
- Frontmatter test: accepts mode: all for director (needs primary + subagent)

## 0.3.0 — 2026-05-26

### Added
- Director as working agent (`.opencode/agents/director.md`) with `task: allow` permission
- Lifecycle state tracking (`.kodehold-state`) — persistent state per project
- Automated quality gates (`scripts/gate.sh`) — 5 transitions with structural checks
- Workspace system (`scripts/workspace.sh`) — init, list, state, gate, deploy-ready
- Project catalog (`workspaces/.catalog`) — JSON registry of all managed projects
- Second opinion protocol — triggers on new ADRs, security-critical, complex decisions
- State awareness in all 5 subagents — check `.kodehold-state` before work, refuse in wrong phase
- Agent refusal/escalation protocol — agents report current vs required state + suggested gate
- Scribes documentation workflow — README, CHANGES, TODO, VERSION creation
- Centralized ICM — all project memory in kodehold `.icm/`, no per-project databases
- Gate support for pytest workspaces (venv detection, PYTHONPATH, `python3` compatibility)
- Architectural decision to remove per-workspace ICM in favour of central store

### Changed
- AGENTS.md simplified to quick reference — full definition in `.opencode/agents/director.md`
- `opencode.json` — director agent registered with `task: allow`
- All 5 subagent files — state awareness sections with allowed phases and escalation paths
- Reviewers — second opinion triggers documented, structured report format
- Architects — design doc status workflow, ADR triggers second opinion
- Scribes — pre-transition storage requirement, documentation file responsibilities
- Testers — state awareness for ACTIVE/REVIEW phases
- `.gitignore` — added `.kodehold-state` and `workspaces/`
- Test suite — adapted for director (frontmatter `task: allow`, transition checks in both AGENTS.md and director.md)

### Fixed
- Gate `scripts/gate.sh` — removed kodehold-infrastructure checks from INIT→ACTIVE (`.opencode/agents`)
- Gate `scripts/gate.sh` — added pytest support for workspace projects (venv, PYTHONPATH, python3)
- Gate `scripts/gate.sh` — made TODO.md optional, made .icm/ optional for workspaces
- Gate `scripts/gate.sh` — dual test runner support (tests/run.sh or pytest)

### Validated
- Full lifecycle run with `lib-validate` workspace: INIT → ACTIVE → REVIEW → CLOSED
- 3 gates passed (INIT_TO_ACTIVE, ACTIVE_TO_REVIEW, REVIEW_TO_CLOSED)
- 3 team delegation rounds (Architects, Reviewers, Engineers, Testers, Reviewers)
- 2 fix rounds (5 design issues + 4 implementation issues)
- Second opinion on ADR-0001 (minor concerns, all addressed)
- 254 tests passing in workspace
- Scribes documented 5 memories in central ICM

## 0.2.0 — 2026-05-25

### Added
- Director orchestrator (`AGENTS.md`) with lifecycle states, quality gates, token budgets, ICM protocol, second opinion triggers
- `opencode.json`: Ollama provider, project permissions (no hardcoded default model)
- 5 team subagents (`.opencode/agents/`): Architects, Engineers, Reviewers, Testers, Scribes
  - Each with YAML frontmatter, responsibilities, workflow, constraints (no model overrides)
- Shared protocol reference (`.opencode/references/kodehold-protocol.md`)
- Test suite: 10 tests across smoke, init, and integration
- CI workflow (`.github/workflows/kodehold-ci.yml`) with 3 parallel jobs
- Shipping gate protocol (8-step process in AGENTS.md + `scripts/ship.sh`)
- ICM knowledge graph: 5 memoirs, 33 concepts, 21 links, 65 memories

### Changed
- ADR-0005 rewritten: bring-your-own-model, light mode optional (KODEHOLD_LIGHT=1), no per-team model config, Ollama as option not default
- Design doc LLM Support section updated to match ADR-0005
- All agent files: model overrides removed — teams inherit user's default OpenCode model
- Protocol reference: light mode marked as optional

### Fixed
- CI: actions/checkout upgraded to v6, setup-python to v6, Node24 opt-in
- CI: ICM download URL corrected to use specific release tag and asset name
- CI: ICM database bootstrap step added before init tests
- Test: ICM init test now auto-creates DB if missing, graceful warn instead of hard-fail
- Test: removed assertion for hardcoded model field in opencode.json
- ADR index: design doc now lists all 8 ADRs with proper references

## 0.1.0 — 2026-05-25

### Added
- Design document (`docs/design/README.md`) — full architecture, team structure, lifecycle
- 8 Architecture Decision Records covering all design constraints:
  - ADR-0001: Foundation and principles
  - ADR-0002: Director + 5 teams (Architects, Engineers, Reviewers, Testers, Scribes)
  - ADR-0003: Design document lifecycle with review gates
  - ADR-0004: ICM and RTK integration strategy
  - ADR-0005: LLM support with Ollama and light mode (32k context)
  - ADR-0006: Second opinion protocol for cross-model validation
  - ADR-0007: Token optimization strategy (English-only, tiered loading, budgets)
  - ADR-0008: Project lifecycle with reopen and archive protocol
- ADR index (`docs/adr/README.md`)
- `.gitignore` excluding `.icm/` directory
- Top-level README, VERSION, TODO, CHANGES
- GitHub repository initialized at `github.com/Acharnite/kodehold`
- ICM persistent memory store initialized
