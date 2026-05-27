# TODO

## Completed

- [x] ADR-0011: Team Meeting — Collective Project Review
- [x] **Team meeting feature** — replaces solo Director final approval
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
- [x] ADR-0006 updated: cross-provider second opinion (Claude/Codex), fallback til brugerprompt
- [x] Second opinion cross-provider krav — implementeret i Director og Reviewers agenter
- [x] Scribes agent opdateret til MCP tools (icm_memory_store, icm_memory_recall)
- [x] ICM naming convention — 7 nye memoirs, 6 team learnings topics, konsistent navnestruktur
- [x] ICM Knowledge Flow (6-step) — implementeret i alle 6 agenter
- [x] Feedback tool references — tilføjet til Director og Reviewers (icm_feedback_record/icm_feedback_search)
- [x] Initial memoirs for KodeHold architecture — 12 team/domain memoirs oprettet

## High Priority

- [x] **Exercise FLS flow** — FLS triaged + fixed 2 crashes (regex(-1), validate(-1)) on lib-validate. 254 tests passed.
- [x] **Exercise reopen flow** — FLS escalation (async validators) → CLOSED→REOPEN→ACTIVE→REVIEW→CLOSED. ADR-0002, 48 async tests, 302 total.
- [x] **Test auto-dedup behavior** — verified: >85% hybrid similarity i samme topic → opdaterer eksisterende (samme ID returneres). Forskellig memory → nyt ID.
- [x] **Measure recall quality** — hybrid search (70% vector + 30% BM25) fanger semantisk mening. "authorization" matcher login/auth/JWT selvom ordet ikke findes i teksten. FTS5-only ville give 0 resultater.
- [x] **Study ICM docs** — architecture, features, guide, integrations, product read. Key insights recorded in kodehold-learnings

- [x] **Use icm_memory_extract_patterns** — testet mod kodehold-session-checkpoint (4 entries). Detected 1 pattern, created concept i kodehold-learnings. Auto-name = første keyword. Bedst når topics har 5+ entries.
- [x] **Consolidation threshold awareness** — added as step 4 (pre-store check) i ICM Knowledge Flow i alle 6 agenter. Tjekker >5 entries, konsoliderer før lagring.
- [x] **OpenCode ICM plugin** — run `icm init --mode hook` to install auto-extraction hooks for session.created, tool.execute.after

## Medium Priority

- [x] **Design doc discipline** — agents must read design doc before work and update it with results when done (enforce via agent files)
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
