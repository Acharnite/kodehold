# TODO

## Completed

- [x] Design document with architecture, team structure, lifecycle
- [x] 8 ADRs covering all design constraints
- [x] Director orchestrator with lifecycle states, quality gates, ICM protocol
- [x] 5 team subagents (Architects, Engineers, Reviewers, Testers, Scribes)
- [x] opencode.json with Ollama provider and permissions
- [x] AGENTS.md, README.md, VERSION.md, TODO.md, CHANGES.md
- [x] ICM memories, memoirs, concepts, links for full knowledge graph
- [x] Test suite: 10 tests (smoke/init/integration) with CI workflow
- [x] Shipping gate protocol with scripts/ship.sh

## High Priority

- [ ] Implement Director — the top-level orchestrator (init, assign, review, close, reopen)
- [ ] Implement team subagents (Architects, Engineers, Reviewers, Testers, Scribes)
- [ ] Write `opencode.json` with team configurations
- [ ] Define AGENTS.md with subagent definitions and conventions
- [ ] Implement project init workflow (design doc creation, ADR bootstrapping)

## Medium Priority

- [ ] Implement light mode (32k context) with collapsed teams
- [ ] Implement second opinion protocol
- [ ] Add token budget tracking per team/phase
- [ ] Implement reopen protocol with ICM context restoration
- [ ] Create `.opencode/` directory with subagent specs

## Low Priority

- [ ] Add example project to demonstrate the workflow
- [ ] Write integration tests for the orchestrator
- [ ] Performance benchmarks comparing token usage with/without RTK
- [ ] CI pipeline for ADR validation
