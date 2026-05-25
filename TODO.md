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

## High Priority

- [ ] Implement Director as working orchestrator — delegate tasks to teams via Task tool
- [ ] Implement Architects agent workflow — design doc init, ADR creation via subagent
- [ ] Implement Engineers agent workflow — code from design spec
- [ ] Implement Reviewers agent workflow — review gate coordination
- [ ] Implement Testers agent workflow — test authoring and execution
- [ ] Implement Scribes agent workflow — ICM store/recall on session boundaries
- [ ] Create `docs/decisions/` directory for working notes
- [ ] Create `.opencode/skills/` directory for future skills

## Medium Priority

- [ ] Implement light mode (KODEHOLD_LIGHT=1) with collapsed Quality team
- [ ] Implement second opinion protocol with cross-model validation
- [ ] Add token budget tracking per team/phase
- [ ] Implement reopen protocol with ICM context restoration
- [ ] Run KodeHold against a real test project to validate the full flow

## Low Priority

- [ ] Add example project to demonstrate the workflow
- [ ] Expand test suite beyond 10 tests
- [ ] Performance benchmarks comparing token usage with/without RTK
- [ ] CI pipeline for ADR format validation
