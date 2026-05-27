# TODO

## Completed

- [x] Design document with architecture, team structure, lifecycle
- [x] 10 ADRs covering all design constraints (0001–0010), all Accepted
- [x] Director orchestrator (AGENTS.md + `.opencode/agents/director.md`) with lifecycle states, quality gates, ICM protocol, second opinion, shipping gate
- [x] 6 team subagents (Architects, Engineers, Reviewers, Testers, Scribes, FLS) with YAML frontmatter
- [x] opencode.json with Ollama provider (no hardcoded default model — user's global OpenCode model used)
- [x] AGENTS.md, README.md, VERSION.md, TODO.md, CHANGES.md, .gitignore
- [x] ICM memories, memoirs, concepts, links — 144 memories, 7 memoirs
- [x] Test suite: 10 tests (smoke/init/integration) with GitHub Actions CI (3 jobs)
- [x] Shipping gate protocol with scripts/ship.sh (8-step process)
- [x] Director as working agent with `task: allow`
- [x] Lifecycle state tracking (.kodehold-state) with gate automation (scripts/gate.sh)
- [x] Workspace system (scripts/workspace.sh) with project registry (.catalog)
- [x] State awareness in all 6 subagents — check state before work, refuse in wrong phase
- [x] Second opinion protocol — implemented and tested on ADR-0001
- [x] Scribes documentation workflow — README, CHANGES, TODO, VERSION per project
- [x] Centralized ICM — no per-project databases
- [x] Proof-of-concept: lib-validate through full INIT→ACTIVE→REVIEW→CLOSED lifecycle
- [x] Agent refusal/escalation protocol with state guidance
- [x] Setup ICM MCP server — respects local databases
- [x] `docs/decisions/` directory for working notes
- [x] `.opencode/skills/` directory for future skills
- [x] FLS (Front Line Support) team — agent definition, triage criteria, escalation protocol
- [x] ADR-0010: FLS Front Line Support Team
- [x] ADR-0009 promoted from Proposed to Accepted
- [x] ADR-0002 updated: Director + 6 teams (FLS added)
- [x] ADR-0008 updated: FLS triage gateway between CLOSED and REOPEN
- [x] All ADRs follow Nygaard format (validated by smoke test)
- [x] **Default Director agent** — hardcoded as default_agent in opencode.json with mode: primary

## High Priority
- [ ] **Director final approval** — compare design doc with final product before shipping gate; approve/reject gate
- [ ] **Exercise FLS flow** — run FLS triage + hotfix against lib-validate or another project
- [ ] **Exercise reopen flow** — run FLS escalation → CLOSED→REOPEN gate → full lifecycle on a real project
- [ ] **Study ICM docs** (https://github.com/rtk-ai/icm/tree/main/docs) to improve KodeHold ICM integration
- [ ] **ADR-0009 follow-up items:**
  - [ ] Update Scribes agent file to reference MCP tools as primary ICM interface
  - [ ] Add feedback tool references to Director and Reviewers agent files
  - [ ] Test auto-dedup behavior with multiple agents writing to same topic
  - [ ] Measure recall quality improvement with hybrid search vs FTS5-only
  - [ ] Create initial memoirs for existing KodeHold architecture knowledge

### Design

- [ ] **Team meeting feature** — all teams + Director review projects together instead of solo Director review

## Medium Priority

- [ ] **Design doc discipline** — agents must read design doc before work and update it with results when done (enforce via agent files)
- [ ] **Implement light mode** (KODEHOLD_LIGHT=1) with collapsed Quality team (Reviewers + Testers)
- [ ] **Token budget tracking** — per team/phase with alerts when exceeded
- [ ] **Implement reopen protocol** — end-to-end with ICM context restoration (Architects impact analysis → design update → new ADRs)
- [ ] **Architects: research** — use webfetch/websearch before designing new features
- [ ] **Run KodeHold against another real project** — validate full lifecycle and reopen flow on a second workspace
- [ ] **ADR format CI** — add ADR Nygaard format validation to CI pipeline (currently only in smoke tests)

## Low Priority

- [ ] Expand test suite beyond 10 tests — edge cases, failure modes, workspace stress tests
- [ ] Performance benchmarks — token usage with/without RTK, with/without ICM summaries
- [ ] FLS-specific tests — triage logic, escalation trigger, minor fix workflow
- [ ] Auto-generate CHANGES.md entries from git log on ship
- [ ] Workshop: dokumentér KodeHold-metoden så nye teams kan onboardes
