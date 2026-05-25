# Changelog

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
