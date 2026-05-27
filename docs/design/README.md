# KodeHold — Coding Orchestrator Design Document

**Version:** 1.0  
**Status:** Draft  
**Last Updated:** 2026-05-25

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

| Phase | Review Type | By |
|-------|------------|-----|
| Draft | Design Review | Reviewers + Architects |
| During Implementation | Incremental Review | Reviewers |
| Before Close | Team Meeting (ADR-0011) | All 6 teams — collective review |
| On Reopen | Impact Review | Architects + Reviewers |

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

### 6.2 Reopening

When a project is reopened:
1. Director loads project context from ICM
2. Design doc is updated with new requirements
3. Impact analysis is performed (Architects + Reviewers)
4. New ADRs are written for significant changes
5. Implementation proceeds as normal lifecycle

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

Configured in `.icm/config.toml`. All project state is persisted here.

### 7.3 RTK (Runtime Toolkit)

RTK is used for all CLI interaction to reduce token consumption:
- `rtk ls`, `rtk read`, `rtk grep`, `rtk tree` for file operations
- `rtk git` for version control
- `rtk find` for file discovery
- Compact output format reduces tokens by 40-60%

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
| Minimal prompts | All agent messages | 20-30% |
| Chunked processing | Large file handling | 50-70% |
| Token budget tracking | All operations | Variable |
| English-only configs | All configuration | ~15% vs Danish |

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
│   └── skills/                    # Optional skills (future)
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
