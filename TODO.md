# TODO

## Completed

- [x] Design document with architecture, team structure, lifecycle
- [x] 8 ADRs covering all design constraints
- [x] Director orchestrator (AGENTS.md) with lifecycle states, quality gates, ICM protocol, second opinion, shipping gate
- [x] 5 team subagents (Architects, Engineers, Reviewers, Testers, Scribes) with YAML frontmatter
- [x] opencode.json with Ollama provider (no hardcoded default model — user's global OpenCode model used)
- [x] AGENTS.md, README.md, VERSION.md, TODO.md, CHANGES.md, .gitignore
- [x] ICM memories, memoirs, concepts, links — 5 memoirs, 33+ concepts, 21+ links, 65 memories
- [x] Test suite: 10 tests (smoke/init/integration) with GitHub Actions CI (3 jobs)
- [x] Shipping gate protocol with scripts/ship.sh (8-step process)
- [x] ADR-0005 corrected: bring-your-own-model, light mode optional (KODEHOLD_LIGHT=1)
- [x] CI fixes: Node24 upgrade (actions/checkout@v6, setup-python@v6), ICM bootstrap
- [x] All model overrides removed from agent files — teams inherit default from OpenCode
- [x] Director as working agent (.opencode/agents/director.md) with task: allow
- [x] Lifecycle state tracking (.kodehold-state) with gate automation (scripts/gate.sh)
- [x] Workspace system (scripts/workspace.sh) with project registry (.catalog)
- [x] State awareness in all 5 subagents — check state before work, refuse in wrong phase
- [x] Second opinion protocol — implemented and tested on ADR-0001
- [x] Scribes documentation workflow — README, CHANGES, TODO, VERSION per project
- [x] Centralized ICM — no per-project databases
- [x] Proof-of-concept: lib-validate through full INIT→ACTIVE→REVIEW→CLOSED lifecycle
- [x] Agent refusal/escalation protocol with state guidance

## High Priority

- [ ] Create `docs/decisions/` directory for working notes
- [ ] Create `.opencode/skills/` directory for future skills

## Medium Priority

- [ ] Implement light mode (KODEHOLD_LIGHT=1) with collapsed Quality team
- [ ] Add token budget tracking per team/phase
- [ ] Implement reopen protocol with ICM context restoration
- [ ] Architects: research inspiration via web search before designing (webfetch/websearch)
- [ ] Run KodeHold against another real project to validate reopen flow

## Low Priority

- [ ] Expand test suite beyond 10 tests
- [ ] Performance benchmarks comparing token usage with/without RTK
- [ ] CI pipeline for ADR format validation
