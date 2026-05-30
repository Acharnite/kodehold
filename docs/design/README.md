# KodeHold — Coding Orchestrator Design Document

**Version:** 1.4.22  
**Status:** Active  
**Last Updated:** 2026-05-30

---

## 1. Overview

KodeHold is a coding orchestrator that applies conscious team-based software engineering methodology to AI-assisted development. It simulates a structured software organization where specialized AI agents collaborate under a Director to produce high-quality code.

The orchestrator is design-document-centric: every project begins with a design document, all teams work from it, and it is continuously reviewed and updated throughout the project lifecycle. Projects can be closed and reopened for new features or bug fixes, with full context preserved via persistent memory.

---

## 2. Principles

| # | Principle | Description |
|---|-----------|-------------|
| 1 | **Design-First** | Every project starts with and revolves around a living design document |
| 2 | **Separation of Concerns** | Distinct teams handle design, implementation, review, testing, and memory |
| 3 | **Token-Conscious** | Every operation is evaluated for token cost; RTK is used for efficient output |
| 4 | **Persistent Memory** | ICM stores all project context, decisions, and rationale across sessions |
| 5 | **LLM-Agnostic** | Core works with any LLM; Ollama is primary; second-opinion cross-check supported |
| 6 | **Traceable Decisions** | All architectural decisions are recorded as ADRs in git |
| 7 | **Project Lifecycle** | Projects can be opened, closed, and reopened without losing context |
| 8 | **Safe Operations** | `git clean -fd` must never be executed automatically — it deletes all untracked files and requires explicit user approval |

---

## 3. Organizational Structure

```
┌─────────────────────────────────────────────────┐
│                   DIRECTOR                       │
│  Orchestrates lifecycle, assigns work, gates     │
│  quality, triggers second opinions               │
└─────────────────────────────────────────────────┘
          │            │           │           │           │
          ▼            ▼           ▼           ▼           ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│ARCHITECTS│  │ENGINEERS │  │REVIEWERS │  │ TESTERS  │  │ SCRIBES  │  │   FLS    │
├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤
│Design    │  │Implement │  │Code      │  │Write     │  │ICM       │  │Triage    │
│Documents │  │Features  │  │Review    │  │Tests     │  │Memory    │  │Hotfix    │
│ADRs      │  │Refactor  │  │Design    │  │Verify    │  │Doc       │  │Escalate  │
│Tech      │  │Bugfixes  │  │Review    │  │Regression│  │Changelog │  │Support   │
│Decisions │  │          │  │Standards │  │Perf Test │  │Extract   │  │          │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
```

### 3.1 Director

The Director is the top-level orchestrator. Responsibilities:
- Project lifecycle management (init, develop, review, close, reopen)
- Task assignment to teams based on current phase
- Quality gate enforcement
- Triggering second opinions on critical decisions
- Token budget management

### 3.2 Architects

Design authority for the project. Responsibilities:
- Author and maintain the project Design Document
- Write Architecture Decision Records (ADRs)
- Evaluate technology choices and trade-offs
- Ensure design coherence across the project

### 3.3 Engineers

Implementation team. Responsibilities:
- Generate code from design specifications
- Refactor existing code
- Fix bugs
- Implement features per design doc

### 3.4 Reviewers

Quality assurance through review. Responsibilities:
- Code review against design doc and standards
- Design review and feedback
- Coordinate second opinion requests with Director
- Verify ADR compliance

### 3.5 Testers

Verification team. Responsibilities:
- Write and execute unit, integration, and e2e tests
- Run regression suites
- Performance testing
- Edge case analysis

### 3.6 Scribes

Memory and documentation team. Responsibilities:
- Manage ICM persistent memory (store/retrieve project context)
- Generate and update project documentation
- Maintain CHANGELOG
- Extract knowledge from completed work for future reuse

### 3.7 FLS (Front Line Support)

First line of defense for minor bugs and small changes. Responsibilities:
- Triage incoming issues — determine minor (fix directly) vs major (escalate)
- Apply hotfixes to CLOSED and ACTIVE projects
- Escalate comprehensive issues to REOPEN with impact summary
- Maintain deep knowledge of completed projects for rapid response

See ADR-0010 for full FLS specification.

---

## 4. Design Document Lifecycle

```
[Create] → [Review] → [Approve] → [Implement] → [Update] → [Review] → ...
                                                                    │
                                                          ┌─────────┘
                                                          ▼
                                                    [Project Closed]
                                                          │
                                                    [Reopen for
                                                     new feature/bugfix]
                                                          │
                                                          ▼
                                                    [Update Design Doc]
                                                          │
                                                          ▼
                                                    [Implementation]
```

### 4.1 Design Document Structure

Each design document follows this structure:

```markdown
# Project: [Name]
**Version:** x.y
**Status:** Draft | Active | Updating | Superseded
**Design Authority:** Architects
**Last Reviewed:** YYYY-MM-DD

## 1. Purpose & Scope
## 2. Requirements
## 3. Architecture Overview
## 4. Component Design
## 5. Data Model
## 6. API Design
## 7. Implementation Plan
## 8. Testing Strategy
## 9. ADR Index (links to relevant ADRs)
## 10. Open Questions
## 11. Changelog
```

### 4.2 Review Cadence

| Phase | Review Type | By | Marker |
|-------|------------|-----|--------|
| Before INIT→ACTIVE | Design Review | Reviewers approve design | `.design_reviewed` |
| Before INIT→ACTIVE | Mandatory Second Opinion | Cross-model validation | `.second_opinion_done` |
| ACTIVE — after Architects | Design Review Gate (Gate 1) | Reviewers | `.design_review_v2` |
| ACTIVE — after Engineers | Code Review Gate (Gate 2) | Reviewers | `.code_reviewed` |
| ACTIVE — after Testers | Comprehensive Review (Gate 3) | Reviewers | `.testers_done` |
| Before REVIEW→CLOSED | Team Meeting (ADR-0011) | All 6 teams — collective review | — |
| Before CLOSED→REOPEN | Impact Assessment | Architects assess scope | `.impact_analysis_done` |

Reviewers serve as **gatekeepers** for lifecycle transitions (ADR-0017). Before the Director runs `gate.sh --transition`, Reviewers validate that all transition requirements are met via `gate.sh --validate-only`. This ensures independent quality validation — the Director orchestrates, Reviewers validate.

See ADR-0016 for the full specification of early review gates in ACTIVE phase.
See ADR-0017 for the full specification of Reviewers as gatekeeper and mandatory second opinion.

For automation/CI, INIT→ACTIVE confirmation can be bypassed with `--yes` or
`OPENCODE_NONINTERACTIVE=true`. Marker cleanup must still occur only after the
gate fully passes.

> **Note:** `--yes` must be the **first flag** for proper argument passthrough.
> Example: `bash scripts/gate.sh --yes --validate-only ACTIVE_TO_REVIEW` works,
> but `bash scripts/gate.sh --validate-only --yes ACTIVE_TO_REVIEW` does not.

> **Reviewer Mode:** When `--reviewer-mode` is used, gate.sh outputs structured results including `GATE_RESULT`, `CHECKS`, `MARKERS_REQUIRED`, `MARKERS_CLEANUP`. The `CHECKS` field lists individual check results (e.g., `design_reviewed:PASS,second_opinion_done:FAIL`). The `MARKERS_REQUIRED` field lists markers that must exist for the transition.

---

## 5. Architecture Decision Records (ADRs)

All significant decisions are recorded as ADRs in `docs/adr/` following the Nygard format:

```
ADR-NNNN: Title
Status: Proposed | Accepted | Deprecated | Superseded
Context: Why this decision is needed
Decision: What was decided
Consequences: Trade-offs and follow-ups
```

### ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| ADR-0001 | KodeHold Foundation and Principles | Accepted |
| ADR-0002 | Organizational Structure — Director + Teams | Accepted |
| ADR-0003 | Design Document Lifecycle | Accepted |
| ADR-0004 | ICM and RTK Integration Strategy | Accepted |
| ADR-0005 | LLM Support and Light Mode | Accepted |
| ADR-0006 | Second Opinion Protocol | Accepted |
| ADR-0007 | Token Optimization Strategy | Accepted |
| ADR-0008 | Project Lifecycle and Reopening | Accepted |
| ADR-0009 | ICM MCP Integration | Accepted |
| ADR-0010 | FLS — Front Line Support Team | Accepted |
| ADR-0011 | Team Meeting — Collective Project Review | Accepted |
| ADR-0012 | Adopted Projects — Existing Codebases in KodeHold | Accepted |
| ADR-0013 | Investigate Skill — Systematic Debugging | Accepted |
| ADR-0014 | Status Dashboard — Project Overview | Proposed |
| ADR-0015 | Director Delegation Enforcement via Tool Permissions | Accepted |
| ADR-0016 | Early Review Gates in ACTIVE Phase | Accepted |
| ADR-0017 | Reviewers as Gatekeeper + Mandatory Second Opinion | Accepted |
| ADR-0018 | Centralize All Documentation Under Scribes | Accepted |
| ADR-0019 | Session Context Compression via Periodic ICM Summaries | Accepted |
| ADR-0020 | Hierarchical Memory (Hot/Warm/Cold) | Superseded |
| ADR-0021 | Prospective Memory (Task Queue & Scheduler) | Accepted |
| ADR-0022 | Automated Episodic Extraction | Superseded |
| ADR-0023 | Semantic Memory Automation | Superseded |
| ADR-0024 | Shared Memory (Multi-Agent Alignment) | Deprecated |
| ADR-0025 | A2A Protocol (Agent-to-Agent Coordination) | Deprecated |
| ADR-0026 | Second Opinion Same-Model Bias Enforcement | Proposed |
| ADR-0027 | ICM Knowledge Flow Invocation Modes | Proposed |

See `docs/adr/README.md` for full details.

---

## 6. Project Lifecycle

### 6.1 States

```
INIT → ACTIVE → REVIEW → CLOSED → (REOPEN → ACTIVE)
```

| State | Description |
|-------|-------------|
| INIT | Design doc created, ADRs drafted, project scoped |
| ACTIVE | Implementation in progress, teams working |
| REVIEW | All work completed, Team Meeting review, testing |
| CLOSED | Project complete, context stored in ICM |
| REOPEN | Project resurrected for new feature or bugfix |

### 6.2 Quality Gates (Markers)

Each state transition requires a quality marker before the gate can pass:

| Gate | Required Marker | Created By | Purpose |
|------|----------------|-----------|---------|
| INIT → ACTIVE | `.design_reviewed` | Reviewers | Design quality approved |
| INIT → ACTIVE | `.second_opinion_done` | Reviewers | Cross-model validation completed |
| ACTIVE — Gate 1 | `.design_review_v2` | Reviewers | Design reviewed before implementation |
| ACTIVE — Gate 2 | `.code_reviewed` | Reviewers | Code reviewed before testing |
| ACTIVE → REVIEW | `.testers_done` | Testers | Tests complete before review |
| REVIEW → CLOSED | Team Meeting | All 6 teams | Collective sign-off |
| CLOSED → REOPEN | `.impact_analysis_done` | Architects | Impact assessed before reopening |
| REOPEN → ACTIVE | `.second_opinion_done` | Reviewers | Cross-model validation for updated design |

Markers are deleted by the gate only after a successful transition pass path
(including INIT→ACTIVE confirmation when interactive). All lifecycle markers
are queued and cleaned after REVIEW→CLOSED passes.

**Gatekeeper authority:** Reviewers validate transitions before the Director runs gate.sh (ADR-0017). Reviewers run `gate.sh --validate-only` and return PASS/BLOCKED. The Director runs the actual gate only after Reviewers approve.

The ACTIVE phase enforces sequential flow: **Architects → Gate 1 → Engineers → Gate 2 → Testers → Gate 3**. Each gate marker must exist before the next team starts work.

See ADR-0016 for the full early review gate specification.

### 6.3 Reopening

When a project is reopened:
1. Director loads project context from ICM
2. Design doc is updated with new requirements
3. Impact analysis is performed by Architects → `.impact_analysis_done`
4. New ADRs are written for significant changes
5. CLOSED→REOPEN gate passes → marker cleaned
6. Implementation proceeds as normal lifecycle

### 6.4 Commit Protection Protocol

To prevent data loss (inspired by ADR-0015 through ADR-0019 being lost when sessions ended before committing), KodeHold enforces a commit protection protocol:

- Before any checkpoint, state transition, or session end, untracked files in `docs/adr/`, `docs/design/`, and `.opencode/agents/` must be identified via `git status --short`
- The Director prompts the user for approval before committing any uncommitted files
- Commits use structured messages with conventional commit prefixes:
  - `docs(adr): ADR-00XX - <title>` for new ADR files
  - `docs(design): <description>` for design document changes
  - `config: <description>` for agent configuration changes
- If the user declines, the Director logs the warning in ICM and continues — data loss risk is acknowledged
- Scribes verify file persistence before storing pre-transition context and escalate untracked files to the Director

---

## 7. Integration

### 7.1 OpenCode Compatibility

KodeHold runs as an OpenCode agent or set of agents. All interaction with the file system, LLM, and tools happens through OpenCode's standard interfaces. Configuration is done via `opencode.json` / `opencode.jsonc`.

### 7.2 ICM (Infinite Context Memory)

ICM provides persistent, queryable memory across sessions:
- Project context, design decisions, and rationale stored as memories
- Concept extraction for knowledge reuse across projects
- Session tracking for audit and continuity
- Vector embeddings for semantic retrieval

KodeHold maintains a **central** `.icm/` directory at the project root for all persistent memory. Workspace projects (`workspaces/<name>/`) and adopted projects do **not** receive their own `.icm/` — they share the central store. Each project's memories are scoped via topic prefixes (`kodehold-<project>-*`) for isolation while keeping a single queryable database.

**ICM Knowledge Flow** — the 8-step protocol governing how every team searches, captures, and refines knowledge — is implemented in `.opencode/skills/icm-knowledge-flow/SKILL.md` with team-specific parameters and lifecycle integration documented in `docs/adr/ADR-0027-icm-knowledge-flow-invocation-modes.md`. All 6 team agents parameterize this protocol with team-specific queries, memoir names, and topic namespaces.

### 7.3 RTK (Runtime Toolkit)

RTK is used for all CLI interaction to reduce token consumption:
- `rtk ls`, `rtk read`, `rtk grep`, `rtk tree` for file operations
- `rtk git` for version control
- `rtk find` for file discovery
- Compact output format reduces tokens by 40-60%

### 7.4 Skills System

KodeHold uses OpenCode skills (`.opencode/skills/<name>/SKILL.md`) for reusable,
on-demand instruction sets shared across multiple agents. Skills are loaded
via the `skill` tool with zero token cost until invoked.

| Skill | Purpose | Used by |
|-------|---------|---------|
| `icm-knowledge-flow` | 7-step ICM memory protocol (search, reflect, store, distill) with 3 invocation modes | All 6 team subagents |
| `state-awareness` | Lifecycle state check preamble and mismatch reporting | All 6 team subagents |
| `investigate` | 4-phase systematic debugging (Iron Law, pattern analysis, 3-strike rule) | FLS, Engineers, Reviewers, Director |

See `docs/adr/ADR-0013-investigate-skill.md` for the full ADR on the investigate skill.

### 7.5 Session Context Compression

On small-context models (Ollama 32K), chat history grows with every delegation round and eventually overflows. Session context compression periodically compresses the running chat into structured ICM summaries, reducing context window pressure.

**Compression triggers:**
| Trigger | Frequency | Rationale |
|---------|-----------|-----------|
| Delegation rounds | Every 4 Task tool invocations | Catches growth before critical |
| State transitions | After every gate passes | Natural summary point |
| Explicit request | User says "compress" / "summarize" | Manual override |

**Summary structure:** Each summary is a 200-400 token document covering: completed work, in-progress items, decisions made, files changed, team assignments, blockers, and context carry-forward. Stored in ICM topic `kodehold-<project>-session-summary` with importance `high`.

**Relationship to checkpoints:**
| Aspect | Summary | Checkpoint |
|--------|---------|------------|
| Purpose | Compress running chat | Snapshot full project state |
| Frequency | Every 4 rounds | Every 8 rounds OR state transition |
| Content | Decisions, changes, assignments | Full state: completed, in-progress, next |
| Importance | `high` | `critical` |

**Wake-up integration:** Session start loads the latest summary via `icm_memory_recall` after the standard `icm_wake_up`, providing immediate "what happened last time" context.

**Consolidation:** When `session-summary` topic exceeds 10 entries, oldest 5 are consolidated into a single "session history" entry.

See ADR-0019 for the full specification.

### 7.6 Adopted Project Symlinks (ADR-0012)

When KodeHold adopts an existing project, `workspace.sh adopt` creates a **symlink** from `workspaces/<name>/` to the real project directory. This is a symlink, not a copy — the project stays at its original location.

**Path behavior:**
| Operation | Path | Resolves To |
|-----------|------|-------------|
| File access | `workspaces/<name>/src/file.py` | `<real_path>/src/file.py` |
| Real path | `realpath workspaces/<name>/` | `<real_path>/` |
| Git operations | `git -C workspaces/<name>/` | `<real_path>/` |
| Module imports | Through symlink | Transparent — imports work normally |

**Agent guidance:**
- **Engineers:** Use the symlink path for consistency. Module imports and build commands resolve through symlinks transparently.
- **Testers:** Symlinked paths can cause test collection failures (pytest, jest). Use `realpath` to resolve to the absolute path when test discovery fails. Set `PYTHONPATH`/`NODE_PATH` to the real path.
- **All teams:** Use `realpath workspaces/<name>` to verify the symlink target exists before relying on it.

**Known issues (ADR-0012):**
- Symlinks break if the target is moved without recreating the symlink
- Some test frameworks produce confusing errors on symlinked paths
- Error messages may show the symlink path instead of the real path

### 7.7 Prospective Memory (ADR-0021)

Prospective memory enables deferred actions, recurring tasks, and future intentions that survive session boundaries. Instead of losing "I should check X next time" when a session ends, tasks are stored in ICM and checked at session start.

**Scope (v1):**
- Deferred tasks — execute after a timestamp
- Recurring tasks — re-create after execution (no scheduler — AI agents have no time sense)

**Out of scope (future):**
- Trigger-based execution — requires event monitoring that AI agents cannot do reliably

#### Storage Format

Tasks are stored as ICM memories in topic `kodehold-<project>-prospective`. The content field uses a structured format that ICM's hybrid search can query:

```
[PROSPECTIVE-TASK]
id: <short-uuid>
type: deferred|recurring
action: <what to do — plain language>
execute_after: <ISO 8601 timestamp>
recurring_interval: <duration, e.g. "2d", "1w">  (recurring only)
priority: critical|high|medium|low
context: <additional context needed to execute>
created_at: <ISO 8601 timestamp>
status: pending
```

**ICM parameters per task:**
- Topic: `kodehold-<project>-prospective`
- Importance: maps from priority (critical→critical, high→high, medium→medium, low→low)
- Keywords: `["prospective", "task-type:<type>", "status:pending"]`

#### Task Types

| Type | Fields | Behavior |
|------|--------|----------|
| **Deferred** | `execute_after` | Checked at session start. If `execute_after <= now()` → present to Director. One-shot. |
| **Recurring** | `execute_after` + `recurring_interval` | Same as deferred, but after execution, Scribes re-creates with `execute_after = now + interval`. |

#### Session-Start Integration

Add a new step in Director's session lifecycle (section "Session Lifecycle" in director.md), between step 1 (ICM context) and step 2 (session summary):

```
1.5. Check prospective tasks:
     icm_memory_recall(topic="kodehold-<project>-prospective", limit=10)
     Filter: status=pending AND execute_after <= now()
     If due tasks found → present to user as "Pending tasks:"
     User decides: execute now / skip / dismiss
```

This is a lightweight check — one ICM query, filtered in-context. No new scripts or tools.

#### Task Lifecycle

```
Created → Pending → [Due] → Executing → Completed
                                        ↓
                               Re-created (recurring) or forgotten (deferred)
```

- **Created:** Scribes stores via `icm_memory_store` with status=pending
- **Due:** Session-start check finds `execute_after <= now()` — presented to Director
- **Executing:** Director delegates to appropriate team
- **Completed:** Scribes updates status via `icm_memory_update` or forgets via `icm_memory_forget`
- **Recurring re-create:** After completion, Scribes stores new task with `execute_after = now + interval`

#### Token Budget

| Priority | Max Tasks | Rationale |
|----------|-----------|-----------|
| Critical | 5 | Must execute — blocking issues |
| High | 10 | Important but not blocking |
| Medium | 15 | Nice-to-have deferred actions |
| Low | 5 | Recurring maintenance |

Total: ~35 tasks max. Scribes enforces by expiring oldest low-priority tasks when limit is reached.

#### TODO.md Integration

Prospective tasks are **separate** from TODO.md. TODO.md tracks "what we're building now"; prospective memory tracks "what to do later." A summary line in TODO.md can reference active prospective task count:

```markdown
## Prospective Tasks
- 3 deferred tasks in ICM (next due: 2026-06-01)
```

Scribes updates this line when creating/expiring tasks.

---

## 8. LLM Support

### 8.1 Bring Your Own Model

KodeHold does not mandate a specific LLM model. The user's global OpenCode model configuration is used as the default for all operations. No per-team model overrides are set in agent definitions — all teams inherit the same default model.

Ollama is available as an optional local provider for users who want private inference. The provider configuration in `opencode.json` enables Ollama as an option without forcing its use.

### 8.2 Light Mode (32k Context)

An optional execution mode for users who want to run KodeHold on a local LLM with at least 32k context. Activated by `KODEHOLD_LIGHT=1`:
- Aggressive RTK usage for all tool output
- ICM summaries instead of full context loading
- Chunked processing for large files
- Minimal prompt templates
- 28k token budget per operation
- Collapsed Reviewers + Testers into single Quality team
- English-only responses (~15% token savings)

### 8.3 Second Opinion

For critical decisions, the Director can request a second opinion from a different AI model:
- Design decisions above a complexity threshold
- Security-critical code
- Architectural trade-offs
- Cross-model validation for bug-prone areas

Protocol:
1. Director identifies a decision requiring second opinion
2. Context is packaged (design doc excerpt + code + question)
3. Request is sent to secondary LLM (different model/provider)
4. Response is fed back to the primary workflow
5. Director reconciles differences or escalates

---

## 9. Token Optimization Strategy

| Technique | Application | Est. Savings |
|-----------|------------|--------------|
| RTK compact output | All CLI commands | 40-60% |
| ICM summaries | Context loading | 30-50% |
| Session context compression | Running chat history | 60-80% per cycle |
| Minimal prompts | All agent messages | 20-30% |
| Chunked processing | Large file handling | 50-70% |
| Token budget tracking | All operations | Variable |
| English-only configs | All configuration | ~15% vs Danish |

### Token Budget Tracking Details

Token budget tracking is implemented via a lightweight protocol:

1. **Token usage script** (`scripts/token-usage.sh`): Queries OpenCode's SQLite database for aggregated token counts per agent (team) within a time window. Outputs JSON with per-team token consumption.

2. **Director's warning protocol**: Before each delegation, Director runs the token-usage script and compares usage against per-phase budgets (ADR-0007). If any team exceeds 80% of its phase budget, a warning is issued; if exceeds 100%, the user is alerted and suggested to compress context.

3. **Session compression logging**: During session compression, Scribes runs the token-usage script and includes per-team token consumption in the ICM summary (field `TokenUsage`). This provides a historical record of token usage across sessions.

4. **Checkpoint token usage**: Session checkpoints also include token usage per team, enabling quick assessment when resuming.

The script provides approximate token counts based on OpenCode's aggregated session data. It is not real-time but reflects cumulative usage per team for the current project.

---

## 10. File Layout

```
kodehold/
├── .icm/                          # ICM persistent memory store
│   ├── config.toml
│   └── memories.db
├── .opencode/                     # OpenCode agent/subagent configs
│   ├── opencode.json              # Local overrides
│   ├── agents/
│   │   ├── architects.md          # Design authority
│   │   ├── engineers.md           # Implementation team
│   │   ├── fls.md                 # Front Line Support
│   │   ├── reviewers.md           # Code/design review
│   │   ├── testers.md             # Verification team
│   │   └── scribes.md             # Memory and documentation
│   ├── references/
│   │   └── kodehold-protocol.md   # Shared protocol reference
│   └── skills/                    # Reusable skills
│       ├── README.md              # Skill index
│       ├── icm-knowledge-flow/
│       │   └── SKILL.md           # 8-step ICM knowledge flow
│       ├── investigate/
│       │   └── SKILL.md           # Systematic debugging protocol (4 phases)
│       └── state-awareness/
│           └── SKILL.md           # Lifecycle state checking + mismatch protocol
├── docs/
│   ├── design/
│   │   └── README.md              # This file — main design document
│   ├── adr/
│   │   ├── README.md              # ADR index
│   │   ├── ADR-0001-*.md
│   │   └── ...
│   └── decisions/                 # Working notes, options analysis
├── .github/workflows/
│   └── kodehold-ci.yml            # CI pipeline (smoke, init, integration)
├── scripts/
│   └── ship.sh                    # Shipping gate checklist automation
├── tests/
│   ├── run.sh                     # Test suite runner
│   ├── smoke/                     # Structure validation
│   ├── init/                      # Configuration validation
│   └── integration/               # Orchestrator flow validation
├── opencode.json                  # OpenCode project configuration (Ollama provider, permissions)
├── AGENTS.md                      # Director — orchestrator, lifecycle, quality gates
├── README.md                      # Project overview
├── VERSION.md                     # Version history
├── TODO.md                        # Task list
├── CHANGES.md                     # Changelog
└── .gitignore                     # Git ignore rules
```

---

## 11. Changelog

- **v1.4.22 (2026-05-30):** ICM memoir restructure — 7 team memoirs consolidated into `kodehold-teams` (27 concepts, 16 links). Learnings consolidated into `kodehold-learnings` (63 concepts, 68 links). All ADR references in ADR-0027, ADR-0023, ADR-0009 updated. CHANGES.md, VERSION.md bumped to 0.17.0.
- **v1.4.21 (2026-05-29):** Implemented ADR-0021 — Prospective Memory (Task Queue & Scheduler). Added section 7.7 to design doc. Updated director.md session lifecycle with prospective task check (step 1.5). Updated scribes.md with Prospective Memory CRUD operations. ADR-0021 status promoted to Accepted. Scope: deferred + recurring tasks only; trigger engine deferred to future.
- **v1.4.20 (2026-05-29):** ADR-0027 implementation review fixes — SKILL.md renumbered to match ADR-0027 step numbering (steps 1-2 Pre-task, steps 4-8 Post-task, step 3 removed from knowledge flow). docs/icm-knowledge-flow.md updated with ADR-0027 reference, 3 invocation modes, Scribes Post-task-only documentation, consolidation threshold fixed (>5→>7). Fixed `memoit=` typo to `memoir=`. Added Full mode to Mode Selection table. Updated second-opinion.md with Post-task mode declaration.
- **v1.4.19 (2026-05-29):** Updated all 6 agent files with ADR-0027 invocation modes (Pre-task/Post-task). Scribes uses Post-task only; other teams use Pre-task default. Fixes token waste and semantic confusion.
- **v1.4.18 (2026-05-29):** Registered ADR-0027 — ICM Knowledge Flow Invocation Modes (Proposed). Added to ADR index in both `docs/adr/README.md` and design doc ADR table.
- **v1.4.17 (2026-05-29):** Fixed missing YAML frontmatter in ICM Knowledge Flow skill file (`.opencode/skills/icm-knowledge-flow/SKILL.md`). Skill now registers correctly with OpenCode's skill discovery.
- **v1.4.16 (2026-05-29):** Registered ADR-0026 — Second Opinion Same-Model Bias Enforcement (Proposed). Added to ADR index in both `docs/adr/README.md` and design doc ADR table.
- **v1.4.15 (2026-05-29):** Shipping gate alignment — AGENTS.md and ship.sh now agree on step count (8 total: 1 manual Team Meeting + 7 automated). CHANGES.md check upgraded from warn to fail.
- **v1.4.14 (2026-05-29):** Fixed FLS→Scribes protocol inconsistency (bug #15) — removed direct ICM storage from FLS workflow, now delegates through Director→Scribes per ADR-0010.
- **v1.4.13 (2026-05-29):** Added Dependabot configuration (`.github/dependabot.yml`) for weekly automated dependency updates — GitHub Actions and npm packages in `.opencode/`.
- **v1.4.12 (2026-05-29):** GitHub MCP server upgrade — replaced deprecated `@modelcontextprotocol/server-github` npm package with official `github/github-mcp-server` Go binary v1.1.2. Eliminates intermittent authentication failures. Closed issues #22 (stale test count) and #25 (GitHub MCP auth).
- **v1.4.11 (2026-05-29):** Fixed ADR-0019 status to "Accepted" across all ADR files (ADR-0019 file, ADR README index). Design doc already had correct status.
- **v1.4.10 (2026-05-29):** Documentation audit and fixes — corrected test count (10 → 12), marked light mode as complete, fixed version header consistency, updated README.md ADR range and test count, closed stale GitHub issues (#4, #5).
- **v1.4.9 (2026-05-29):** Added ADR-0020 through ADR-0025 — AI Agent Memory Stack features: Hierarchical Memory (Hot/Warm/Cold), Prospective Memory (Task Queue & Scheduler), Automated Episodic Extraction, Semantic Memory Automation, Shared Memory (Multi-Agent Alignment), and A2A Protocol (Agent-to-Agent Coordination). All status: Proposed.
- **v1.4.8 (2026-05-29):** Implemented ADR-0019 — Session Context Compression. Updated director.md with compression triggers every 4 rounds, summary template, and consolidation policy. Updated scribes.md with summary template, escalation path for large topics. ADR-0019 status promoted to Accepted. This completes the last remaining KODEHOLD_LIGHT=1 component.
- **v1.4.7 (2026-05-29):** Added Principle #8 — Safe Operations (no automatic `git clean -fd`). Added corresponding constraints in director.md and AGENTS.md. Added Commit Protection Protocol — prevents data loss from uncommitted ADR, design, and agent files at session end. Updated Director agent with 5-step protocol, Scribes agent with file persistence verification step in pre-transition workflow, and design doc section 6.4.
- **v1.4 (2026-05-28):** Added ADR-0017 — Reviewers as gatekeeper for lifecycle transitions and mandatory second opinion on ADRs/design documents. Updated Review Cadence (4.2) with gatekeeper authority and `.second_opinion_done` marker. Updated Quality Gates (6.2) with second opinion markers for INIT→ACTIVE and REOPEN→ACTIVE.
- **v1.4.1 (2026-05-28):** ADR-0017 status updated to Accepted. Documented `--yes` flag ordering constraint in gate.sh (must be first flag).
- **v1.4.2 (2026-05-28):** gate.sh `--reviewer-mode` output now includes `CHECKS` and `MARKERS_REQUIRED` fields per ADR-0017. `CHECKS` lists individual check results (e.g., `design_reviewed:PASS,second_opinion_done:FAIL`). `MARKERS_REQUIRED` lists markers required for the transition.
- **v1.4.3 (2026-05-28):** Added ADR-0019 — Session context compression via periodic ICM summaries. Added section 7.5 (Session Context Compression) to Integration. Updated token optimization table with compression savings estimate.
- **v1.4.4 (2026-05-29):** Clarified Section 7.2 (ICM) — workspace/adopted projects do not get their own `.icm/`; all project memory uses the central `.icm/` with topic prefix scoping (`kodehold-<project>-*`).
- **v1.4.5 (2026-05-29):** Fixed ADR status inconsistencies — ADR-0015, ADR-0016 promoted to Accepted; ADR-0019 status updated to "Designed — not yet implemented"
- **v1.3 (2026-05-28):** Added early review gates (ADR-0016) — three-checkpoint review system in ACTIVE phase. Updated Review Cadence (4.2) and Quality Gates (6.2) with Gate 1 (design review, `.design_review_v2`) and Gate 2 (code review, `.code_reviewed`).
- **v1.2 (2026-05-27):** Clarified quality-gate marker semantics so cleanup
  happens only on successful pass paths; documented INIT→ACTIVE non-interactive
  confirmation bypass behavior (`--yes`, `OPENCODE_NONINTERACTIVE=true`).
