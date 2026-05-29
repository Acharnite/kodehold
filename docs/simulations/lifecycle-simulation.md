# KodeHold Lifecycle Simulation

> Complete walkthrough of all KodeHold workflow steps across 4 scenarios.
> Generated for the fictional project **taskflow-api** (Python/FastAPI).

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Actor Reference](#2-actor-reference)
3. [State Reference](#3-state-reference)
4. [Gate Reference](#4-gate-reference)
5. [Scenario 1: New Project — Full Lifecycle](#5-scenario-1-new-project--full-lifecycle)
6. [Scenario 2: Bug Fix (FLS Flow)](#6-scenario-2-bug-fix-fls-flow)
7. [Scenario 3: Large Feature Reopen](#7-scenario-3-large-feature-reopen)
8. [Scenario 4: Adopted Project Flow](#8-scenario-4-adopted-project-flow)
9. [Cross-Reference Matrix](#9-cross-reference-matrix)
10. [Marker Lifecycle](#10-marker-lifecycle)

---

## 1. Introduction

This document provides a step-by-step simulation of the KodeHold project lifecycle across four distinct scenarios. Each scenario demonstrates how the six specialized teams (Architects, Engineers, Testers, Reviewers, Scribes, FLS) collaborate under the Director's orchestration to move a project through its lifecycle states.

### Fictional Project

| Field | Value |
|-------|-------|
| **Name** | `taskflow-api` |
| **Description** | A REST API for task management with user auth, CRUD operations, and webhooks |
| **Language** | Python |
| **Framework** | FastAPI |
| **Repository** | `workspaces/taskflow-api/` |

### Scenarios Overview

| # | Scenario | States Traversed | Step Count |
|---|----------|-----------------|------------|
| 1 | New Project — Full Lifecycle | INIT → ACTIVE → REVIEW → CLOSED | 30 |
| 2 | Bug Fix (FLS) | CLOSED → CLOSED (minor fix) | 6 |
| 3 | Large Feature Reopen | CLOSED → REOPEN → ACTIVE → REVIEW → CLOSED | 26+ |
| 4 | Adopted Project | adopt → INIT → ACTIVE → REVIEW → CLOSED | 9+ |

---

## 2. Actor Reference

| Actor | Agent Type | Role |
|-------|-----------|------|
| **Director** | `director` | Orchestrator. Delegates all work via Task tool. Never implements directly. |
| **Architects** | `architects` | Design documents, ADRs, component design, impact analysis |
| **Engineers** | `engineers` | Code implementation, build configuration, dependency management |
| **Testers** | `testers` | Unit tests, integration tests, test coverage, `.testers_done` marker |
| **Reviewers** | `reviewers` | Code review, design review, gate validation, `.design_reviewed` / `.code_reviewed` markers |
| **Scribes** | `scribes` | Documentation (README, CHANGES, TODO, VERSION), ICM memory storage, design doc updates |
| **FLS** | `fls` | Triage, hotfixes, bug investigation. Uses `investigate` skill. |
| **Second Opinion** | `second-opinion` | Cross-model validation via OpenRouter (e.g., Gemma 3 12B). Independent technology review. |
| **User** | Human | Project owner. Approves designs, confirms transitions, requests features. |

### Team Participation by Phase

| Phase | Architects | Engineers | Testers | Reviewers | Scribes | FLS |
|-------|-----------|-----------|---------|-----------|---------|-----|
| INIT | ✓ | — | — | ✓ | ✓ | — |
| ACTIVE | ✓ | ✓ | ✓ | ✓ | ✓ | ✓* |
| REVIEW | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CLOSED | — | — | — | — | ✓ | ✓* |
| REOPEN | ✓ | ✓ | ✓ | ✓ | ✓ | — |

\* FLS operates in ACTIVE and CLOSED for triage/hotfixes.

---

## 3. State Reference

| State | Description | Key Activities |
|-------|-------------|----------------|
| **INIT** | Project initialized, design in progress | Design doc creation, ADR writing, architecture decisions |
| **ACTIVE** | Implementation underway | Coding, testing, code review, component design detail |
| **REVIEW** | Implementation complete, team review | Team Meeting (all 6 teams), final sign-off |
| **CLOSED** | Project shipped | Version bump, tagging, documentation finalization, memoir distillation |
| **REOPEN** | Closed project reopened for changes | Impact analysis, design updates, then re-enter ACTIVE |

### Valid Transitions

```
INIT → ACTIVE
ACTIVE → REVIEW
REVIEW → CLOSED
CLOSED → REOPEN
REOPEN → ACTIVE
```

### State File

The current state is stored in `.kodehold-state` at the workspace root:

```bash
# Read state
cat workspaces/taskflow-api/.kodehold-state
# Output: STATE=ACTIVE

# State transitions are handled by Director via gate.sh
```

---

## 4. Gate Reference

| Gate | Transition | Required Markers | Created By | Cleaned By |
|------|-----------|-----------------|------------|------------|
| **Gate 0** | INIT → ACTIVE | `.design_reviewed` + `.second_opinion_done` + user confirmation | Reviewers, Second Opinion | gate.sh on pass |
| **Gate 1** | ACTIVE (design detail) | `.design_review_v2` or equivalent design completeness marker | Architects | Reviewers on validation |
| **Gate 2** | ACTIVE → REVIEW | `.code_reviewed` + `.testers_done` | Reviewers, Testers | gate.sh on pass |
| **Gate 3** | REVIEW → CLOSED | Team Meeting approval (6/6 votes) + shipping gate (ship.sh steps 1-7) | All 6 teams | gate.sh on pass |
| **Gate 4** | CLOSED → REOPEN | `.impact_analysis_done` | Architects | gate.sh on pass |

### Gate Check Details

```bash
# Check gate status
bash scripts/gate.sh --project-path workspaces/taskflow-api --transition INIT_TO_ACTIVE

# Gate checks:
# ✓ design doc exists (docs/design/README.md)
# ✓ design doc has all 11 sections
# ✓ at least 1 ADR exists
# ✓ .design_reviewed marker exists
# ✓ .second_opinion_done marker exists
# ✓ user confirmed
```

### Marker Files

| Marker | Created When | Cleaned When | Purpose |
|--------|-------------|-------------|---------|
| `.design_reviewed` | Reviewers approve design doc | Gate passes (INIT→ACTIVE) | Confirms design quality |
| `.second_opinion_done` | Second Opinion validates tech choice | Gate passes (INIT→ACTIVE) | Cross-model confirmation |
| `.design_review_v2` | Architects complete detailed design | Gate 1 validated | Detailed design complete |
| `.code_reviewed` | Reviewers approve code | Gate passes (ACTIVE→REVIEW) | Code quality confirmed |
| `.testers_done` | Testers complete test suite | Gate passes (ACTIVE→REVIEW) | Tests written and passing |
| `.impact_analysis_done` | Architects complete impact analysis | Gate passes (CLOSED→REOPEN) | Scope assessed |
| `.distill_needed` | gate.sh on REVIEW→CLOSED | Scribes remove after distillation | Triggers memoir distillation |

---

## 5. Scenario 1: New Project — Full Lifecycle

### Phase: INIT (Design & Architecture)

---

**Step 1** — **Director** (Session Start)

- Loads ICM context: `icm_memory_recall -t kodehold-taskflow-api -i critical high`
- Reads design doc (not yet exists)
- Checks state: no `.kodehold-state` found → project needs initialization

**Produced:** ICM recall results (empty for new project)

---

**Step 2** — **Director → User**

- User requests: *"Create a new project: taskflow-api — a REST API for task management"*
- Director creates workspace: `bash scripts/workspace.sh init taskflow-api`

**Produced:**
- `workspaces/taskflow-api/` directory with template structure
- `.kodehold-state` → `STATE=INIT`

---

**Step 3** — **Director → Architects** (Task tool)

- **Context:** New project `taskflow-api`, section 4.1 of design doc (Design Document Structure)
- **Task:** Create complete design document with all 11 sections, write ADR-0001 for FastAPI choice
- **Deliverables:** `docs/design/README.md` (filled), `docs/adr/ADR-0001-fastapi-choice.md`, `docs/adr/README.md` updated

---

**Step 4** — **Architects** (executing)

- Researches FastAPI vs Django vs Flask
- Writes design doc sections 1–11 with real content
- Writes ADR-0001: "FastAPI as web framework" (Status: Proposed)
- Updates ADR index

**Produced:**
- `workspaces/taskflow-api/docs/design/README.md` — full design document
- `workspaces/taskflow-api/docs/adr/ADR-0001-fastapi-choice.md` — ADR
- `workspaces/taskflow-api/docs/adr/README.md` — updated index

---

**Step 5** — **Director → Scribes** (Task tool)

- **Context:** Architects completed design doc + ADR
- **Task:** Update VERSION.md (bump to 0.1.0), add CHANGES.md entry, update TODO.md
- **Deliverables:** Updated VERSION.md, CHANGES.md, TODO.md

---

**Step 6** — **Scribes** (executing)

- Bumps VERSION.md to 0.1.0
- Creates CHANGES.md entry: `## 0.1.0 — INIT phase: Design document created`
- Adds TODO.md items for upcoming phases

**Produced:**
- `workspaces/taskflow-api/VERSION.md` → 0.1.0
- `workspaces/taskflow-api/CHANGES.md` — new entry
- `workspaces/taskflow-api/TODO.md` — phase items added

---

**Step 7** — **Director → Reviewers** (Task tool — Gate 1: Design Review)

- **Context:** Design doc + ADR-0001 complete
- **Task:** Review design doc quality, validate all 11 sections, check ADR format compliance. If approved, create `.design_reviewed` marker.
- **Deliverables:** `.design_reviewed` marker created, review feedback

---

**Step 8** — **Reviewers** (executing)

- Reads design doc, checks all 11 sections present and meaningful
- Validates ADR-0001 follows Nygard format
- Creates `.design_reviewed` marker file

**Produced:**
- `workspaces/taskflow-api/.design_reviewed`
- Review feedback: PASS with minor suggestions

---

**Step 9** — **Director → Second Opinion** (subagent)

- **Context:** Design doc + ADR-0001 for taskflow-api
- **Task:** Cross-model validation of FastAPI technology choice. Is FastAPI appropriate for this use case?
- **Deliverables:** Second opinion report

---

**Step 10** — **Second Opinion** (executing via OpenRouter/Gemma 3 12B)

- Reviews FastAPI choice independently
- Returns: *"FastAPI is well-suited — async support, automatic OpenAPI docs, Pydantic integration"*

**Produced:**
- Second opinion report
- Director creates `.second_opinion_done` marker
- `workspaces/taskflow-api/.second_opinion_done`

---

**Step 11** — **Director → User**

- Presents design summary for approval
- User confirms: *"Design looks good, proceed"*
- Director runs: `bash scripts/gate.sh --project-path workspaces/taskflow-api --transition INIT_TO_ACTIVE`

**Gate Checks:**
| Check | Result |
|-------|--------|
| design doc exists | ✓ |
| 11 sections present | ✓ |
| ADRs exist | ✓ |
| `.design_reviewed` exists | ✓ |
| `.second_opinion_done` exists | ✓ |

- Gate PASSES → `.design_reviewed` and `.second_opinion_done` cleaned up
- Director updates `.kodehold-state`: `STATE=ACTIVE`

---

### Phase: ACTIVE (Implementation)

---

**Step 12** — **Director → Architects** (Task tool — Gate 1: Design Review in ACTIVE)

- **Context:** ACTIVE phase started, need detailed component design
- **Task:** Expand sections 4 (Component Design), 5 (Data Model), 6 (API Design) with implementation-ready details
- **Deliverables:** Updated design doc with detailed specs

---

**Step 13** — **Architects** (executing)

- Designs User model, Task model, Webhook model
- Defines API endpoints: `POST/GET/PUT/DELETE /tasks`, `POST /auth/login`, `POST /webhooks`
- Creates `.design_review_v2` marker

**Produced:**
- Updated `workspaces/taskflow-api/docs/design/README.md` — sections 4–6 detailed
- `workspaces/taskflow-api/.design_review_v2`

---

**Step 14** — **Director → Reviewers** (Task tool — Gate 1 validation)

- **Context:** Architects completed detailed design
- **Task:** Review detailed design against requirements. Validate `.design_review_v2` marker exists.
- **Deliverables:** Gate 1 PASS/BLOCKED

---

**Step 15** — **Reviewers** (executing)

- Validates design coherence, API consistency, data model completeness
- Confirms `.design_review_v2` exists

**Gate 1 Result:** PASS

---

**Step 16** — **Director → Engineers** (Task tool)

- **Context:** Gate 1 passed, design doc sections 4–6 detailed
- **Task:** Implement FastAPI application: models, routes, auth middleware, webhook dispatcher
- **Deliverables:** Full implementation in `src/` directory

---

**Step 17** — **Engineers** (executing)

- Creates `src/main.py`, `src/models.py`, `src/routes/`, `src/auth.py`, `src/webhooks.py`
- Implements CRUD for tasks, JWT auth, webhook delivery

**Produced:**
- `workspaces/taskflow-api/src/main.py`
- `workspaces/taskflow-api/src/models.py`
- `workspaces/taskflow-api/src/routes/__init__.py`
- `workspaces/taskflow-api/src/routes/tasks.py`
- `workspaces/taskflow-api/src/routes/auth.py`
- `workspaces/taskflow-api/src/routes/webhooks.py`
- `workspaces/taskflow-api/src/auth.py`
- `workspaces/taskflow-api/src/webhooks.py`

---

**Step 18** — **Director → Reviewers** (Task tool — Gate 2: Code Review)

- **Context:** Engineers completed implementation
- **Task:** Code review against design doc. Check: code matches API design, models match data model, auth follows security best practices. If approved, create `.code_reviewed` marker.
- **Deliverables:** `.code_reviewed` marker, review findings

---

**Step 19** — **Reviewers** (executing)

- Reviews all source files against design doc
- Checks: API endpoints match section 6, models match section 5, security practices

**Produced:**
- `workspaces/taskflow-api/.code_reviewed`
- Review: PASS with 2 minor suggestions (non-blocking)

---

**Step 20** — **Director → Testers** (Task tool)

- **Context:** Gate 2 passed, code reviewed
- **Task:** Write unit tests for models, integration tests for API endpoints, test auth flow
- **Deliverables:** Test files in `tests/` directory

---

**Step 21** — **Testers** (executing)

- Creates `tests/test_models.py`, `tests/test_api.py`, `tests/test_auth.py`
- Runs tests: all pass

**Produced:**
- `workspaces/taskflow-api/tests/test_models.py`
- `workspaces/taskflow-api/tests/test_api.py`
- `workspaces/taskflow-api/tests/test_auth.py`
- `workspaces/taskflow-api/.testers_done`
- Test results: 45 tests, all passing

---

**Step 22** — **Director → Reviewers** (Task tool — Gate 3: Test Verification)

- **Context:** Testers completed, `.testers_done` exists
- **Task:** Verify test coverage is adequate, review test quality. Confirm `.testers_done` marker.
- **Deliverables:** Gate 3 PASS/BLOCKED

---

**Step 23** — **Reviewers** (executing)

- Reviews test coverage: models ✓, API ✓, auth ✓, edge cases ✓
- Confirms `.testers_done` exists

**Gate 3 Result:** PASS

---

### Phase: REVIEW

---

**Step 24** — **Director**

- Runs: `bash scripts/gate.sh --project-path workspaces/taskflow-api --transition ACTIVE_TO_REVIEW`

**Gate Checks:**
| Check | Result |
|-------|--------|
| tests pass | ✓ |
| `.testers_done` exists | ✓ |
| `.code_reviewed` exists | ✓ |

- Gate PASSES → markers cleaned up
- Director updates `.kodehold-state`: `STATE=REVIEW`

---

**Step 25** — **Director → All 6 Teams** (Task tool — Team Meeting, ADR-0011)

- **Context:** Project in REVIEW, all implementation complete
- **Task:** Each team presents their assessment:

| Team | Assessment |
|------|-----------|
| Architects | "Design doc matches implementation" |
| Engineers | "All features implemented per spec" |
| Reviewers | "Code reviewed, quality gates passed" |
| Testers | "45 tests pass, coverage adequate" |
| Scribes | "Documentation complete, ICM stored" |
| FLS | "No triage issues identified" |

- **Final vote:** 6/6 APPROVE

---

**Step 26** — **Scribes** (Task tool)

- **Context:** Team meeting approved
- **Task:** Store project context in ICM
- **Deliverables:** ICM entry with full project summary

```
icm_memory_store -t kodehold-taskflow-api-review -i high
```

**Stored:**
- Project overview, architecture decisions, review results, test results

---

### Phase: Shipping

---

**Step 27** — **Director → User**

- Presents Team Meeting results
- User approves: *"Ship it"*

---

**Step 28** — **Director**

- Runs: `bash scripts/gate.sh --project-path workspaces/taskflow-api --transition REVIEW_TO_CLOSED`

**Gate Checks:**
| Check | Result |
|-------|--------|
| tests pass | ✓ |
| design doc exists | ✓ |
| ICM accessible | ✓ |
| working tree clean | ✓ |

- User confirms: *"Proceed with REVIEW → CLOSED? [Y/n]"* → Y
- Gate PASSES → all lifecycle markers cleaned up, `.distill_needed` created
- Director updates `.kodehold-state`: `STATE=CLOSED`

---

**Step 29** — **Scribes** (Task tool)

- **Context:** Project CLOSED
- **Task:** Run shipping gate steps 1–7: bump VERSION.md to 1.0.0, update CHANGES.md, mark TODO.md items complete, commit all changes

**Produced:**
- `workspaces/taskflow-api/VERSION.md` → 1.0.0
- `workspaces/taskflow-api/CHANGES.md` — v1.0.0 entry
- `workspaces/taskflow-api/TODO.md` — completed items marked

---

**Step 30** — **Director**

- Runs shipping gate: `bash scripts/ship.sh`
- All 7 automated steps pass
- Creates git tag: `git tag v1.0.0 && git push origin v1.0.0`

**Final State:**
```
Project: taskflow-api
State: CLOSED
Version: 1.0.0
Tag: v1.0.0
Steps: 30
Teams involved: All 8 (Director, Architects, Engineers, Testers, Reviewers, Scribes, FLS, Second Opinion)
```

---

## 6. Scenario 2: Bug Fix (FLS Flow)

### Starting State: CLOSED

---

**Step 1** — **User** reports bug

> *"There's a bug: deleting a task that has webhooks attached causes a 500 error"*

---

**Step 2** — **Director → FLS** (Task tool)

- **Context:** Bug report on CLOSED project `taskflow-api`
- **Task:** Triage this bug using investigate skill. Determine if minor (fix directly) or major (escalate to REOPEN).
- **Deliverables:** Triage result + fix or ESCALATE

---

**Step 3** — **FLS** (executing)

- Loads `investigate` skill
- Investigates: finds missing CASCADE delete in Task model for webhook relationship
- Triage decision: **MINOR** — single-line fix, no design changes needed
- Creates hotfix: adds `ondelete="CASCADE"` to webhook foreign key
- Runs tests: all 45 still pass

**Produced:**
- Modified `workspaces/taskflow-api/src/models.py` — CASCADE on webhook FK
- Test results: 45/45 passing

**Return:** *"Fixed. Missing CASCADE on webhook FK. 1 line changed."*

---

**Step 4** — **Director → Scribes** (Task tool)

- **Context:** FLS completed minor hotfix
- **Task:** Store fix in ICM, update CHANGES.md with fix entry
- **Deliverables:** ICM entry, CHANGES.md updated

---

**Step 5** — **Scribes** (executing)

- Stores in ICM: `icm_memory_store -t kodehold-taskflow-api-fixes -i medium`

```
Content: "Fixed cascade delete bug on task-webhook relationship.
          Root cause: missing ondelete='CASCADE' on Webhook.task_id FK.
          Fix: 1 line changed in models.py."
```

- Updates CHANGES.md:
  ```markdown
  ### Fixed
  - Cascade delete for task-webhook relationship (deleting a task with
    attached webhooks no longer causes 500 error)
  ```

**Produced:**
- ICM entry in `kodehold-taskflow-api-fixes`
- Updated `workspaces/taskflow-api/CHANGES.md`

---

**Step 6** — **Director**

- Project remains CLOSED (minor fix, FLS handled it)
- Git commit: `fix(api): cascade delete for task-webhook relationship`
- No state transition needed

**Final State:**
```
Project: taskflow-api
State: CLOSED (unchanged)
Fix applied: Yes (minor, FLS)
State transition: None
Steps: 6
Teams involved: Director, FLS, Scribes
```

---

## 7. Scenario 3: Large Feature Reopen

### Starting State: CLOSED

---

**Step 1** — **User** requests feature

> *"I want to add a real-time notification system using WebSockets"*

---

**Step 2** — **Director → Architects** (Task tool — Impact Analysis)

- **Context:** CLOSED project `taskflow-api`, new feature request: WebSocket notifications
- **Task:** Perform impact analysis. Assess scope, design changes needed, new ADRs required. Create `.impact_analysis_done` marker.
- **Deliverables:** Impact analysis report, `.impact_analysis_done` marker

---

**Step 3** — **Architects** (executing)

- Analyzes impact: requires new WebSocket endpoint, new Notification model, event bus
- Scope: **MAJOR** — new component, new data model, new API surface
- Recommends: ADR-0002 for WebSocket technology choice

**Produced:**
- Impact analysis report
- `workspaces/taskflow-api/.impact_analysis_done`

**Return:** Impact analysis with recommendations

---

**Step 4** — **Director**

- Runs: `bash scripts/gate.sh --project-path workspaces/taskflow-api --transition CLOSED_TO_REOPEN`

**Gate Checks:**
| Check | Result |
|-------|--------|
| design doc exists | ✓ |
| `.impact_analysis_done` exists | ✓ |

- Gate PASSES → `.impact_analysis_done` cleaned
- Director updates `.kodehold-state`: `STATE=REOPEN`

---

**Step 5** — **Director → Architects** (Task tool)

- **Context:** REOPEN state, impact analysis done
- **Task:** Update design doc with new sections for WebSocket notifications. Write ADR-0002: WebSocket technology choice.
- **Deliverables:** Updated design doc, ADR-0002

---

**Step 6** — **Architects** (executing)

- Updates design doc: adds WebSocket component, Notification model, event bus design
- Writes ADR-0002: "WebSocket via FastAPI native support" (Status: Proposed)

**Produced:**
- Updated `workspaces/taskflow-api/docs/design/README.md`
- `workspaces/taskflow-api/docs/adr/ADR-0002-websocket-choice.md`

---

**Step 7** — **Director → Reviewers** (Task tool)

- **Context:** Updated design doc + ADR-0002
- **Task:** Review updated design. Create `.design_reviewed` marker if approved.
- **Deliverables:** `.design_reviewed` marker

---

**Step 8** — **Reviewers** (executing)

- Reviews new design sections for coherence with existing architecture

**Produced:**
- `workspaces/taskflow-api/.design_reviewed`
- Review: PASS

---

**Step 9** — **Director → Second Opinion** (subagent)

- **Context:** ADR-0002 WebSocket technology choice
- **Task:** Cross-model validation of WebSocket approach
- **Deliverables:** Second opinion report

---

**Step 10** — **Second Opinion** (executing)

- Reviews WebSocket choice independently
- Returns: *"FastAPI WebSocket support is mature and appropriate"*

**Produced:**
- Second opinion report
- Director creates `.second_opinion_done` marker
- `workspaces/taskflow-api/.second_opinion_done`

---

**Step 11** — **Director**

- Runs: `bash scripts/gate.sh --project-path workspaces/taskflow-api --transition REOPEN_TO_ACTIVE`

**Gate Checks:**
| Check | Result |
|-------|--------|
| design doc exists | ✓ |
| status is Active | ✓ |
| ADRs exist | ✓ |
| `.second_opinion_done` exists | ✓ |

- Gate PASSES → `.second_opinion_done` cleaned
- Director updates `.kodehold-state`: `STATE=ACTIVE`

---

**Steps 12–23** — Same flow as Scenario 1 ACTIVE phase:

| Step | Actor | Action |
|------|-------|--------|
| 12 | Director → Architects | Detailed component design for WebSocket + Notifications |
| 13 | Architects | Designs Notification model, event bus, WebSocket handler |
| 14 | Director → Reviewers | Gate 1 validation |
| 15 | Reviewers | Gate 1 PASS |
| 16 | Director → Engineers | Implement WebSocket + Notifications |
| 17 | Engineers | Create `src/websockets.py`, `src/notifications.py`, `src/events.py` |
| 18 | Director → Reviewers | Gate 2: Code Review |
| 19 | Reviewers | `.code_reviewed` created, PASS |
| 20 | Director → Testers | Write WebSocket + notification tests |
| 21 | Testers | New tests created, `.testers_done` created, all tests pass |
| 22 | Director → Reviewers | Gate 3: Test Verification |
| 23 | Reviewers | Gate 3 PASS |

---

**Step 24** — **ACTIVE → REVIEW**

- Gate passes, `STATE=REVIEW`

---

**Step 25** — **Team Meeting**

- 6 teams present, 6/6 APPROVE
- Architects: "WebSocket design matches implementation"
- Engineers: "Real-time notifications working end-to-end"
- Reviewers: "Code quality maintained"
- Testers: "New tests pass, existing tests unaffected"
- Scribes: "Documentation updated"
- FLS: "No regression issues"

---

**Step 26** — **REVIEW → CLOSED**

- Gate passes, shipping gate runs
- Git tag: `v1.1.0`
- Project CLOSED with WebSocket notifications added

**Final State:**
```
Project: taskflow-api
State: CLOSED
Version: 1.1.0
Tag: v1.1.0
New features: WebSocket notifications, real-time event bus
Steps: 26+
Teams involved: All 8
```

---

## 8. Scenario 4: Adopted Project Flow

### Starting State: External project exists at `/home/user/my-app`

---

**Step 1** — **User** requests adoption

> *"Adopt my existing project at /home/user/my-app into KodeHold"*

---

**Step 2** — **Director**

- Runs: `bash scripts/workspace.sh adopt my-app /home/user/my-app`

**Produced:**
- Symlink: `workspaces/my-app/ → /home/user/my-app/`
- Scanned project: detects Python, pytest, 150 commits
- Creates retroactive design doc (template with detected info)
- Creates `.kodehold-state` with `ADOPTED=true`, `STATE=INIT`

**Return:** Adoption summary with detected language, framework, commit count

---

**Step 3** — **Director → Architects** (Task tool)

- **Context:** Adopted project `my-app`, retroactive design doc needs filling
- **Task:** Fill in the design document based on existing codebase. Write retroactive ADRs for key architectural decisions already made.
- **Deliverables:** Filled design doc, 2–3 retroactive ADRs

---

**Step 4** — **Architects** (executing)

- Reads existing codebase through symlink
- Fills design doc sections 1–11 based on actual code
- Writes ADR-0001: "PostgreSQL as database" (retroactive, Status: Accepted)
- Writes ADR-0002: "React frontend" (retroactive, Status: Accepted)

**Produced:**
- `workspaces/my-app/docs/design/README.md` — filled retroactive design doc
- `workspaces/my-app/docs/adr/ADR-0001-postgresql-choice.md`
- `workspaces/my-app/docs/adr/ADR-0002-react-frontend.md`

---

**Step 5** — **Director → Reviewers** (Task tool — Design Review)

- **Context:** Adopted project design doc filled
- **Task:** Review retroactive design doc. Create `.design_reviewed` marker.
- **Deliverables:** `.design_reviewed` marker

---

**Step 6** — **Reviewers** (executing)

- Reviews design doc accuracy against codebase
- Validates that retroactive ADRs accurately reflect existing decisions

**Produced:**
- `workspaces/my-app/.design_reviewed`
- Review: PASS

---

**Step 7** — **Director → Second Opinion**

- **Context:** Retroactive design doc for adopted project
- **Task:** Validate design doc accurately represents existing architecture
- **Deliverables:** Second opinion report

---

**Step 8** — **Second Opinion** (executing)

- Returns: *"Design doc is consistent with codebase structure"*

**Produced:**
- Second opinion report
- Director creates `.second_opinion_done` marker
- `workspaces/my-app/.second_opinion_done`

---

**Step 9** — **Director**

- Runs: `bash scripts/gate.sh --project-path workspaces/my-app --transition INIT_TO_ACTIVE`

**Gate Checks:**
| Check | Result |
|-------|--------|
| design doc exists | ✓ |
| sections present | ✓ |
| ADRs exist | ✓ |
| `.design_reviewed` exists | ✓ |
| `.second_opinion_done` exists | ✓ |
| Implementation Plan section | ⚠️ WARN (adopted project — optional) |

- Gate PASSES (warning on Implementation Plan is non-blocking for adopted projects)
- Director updates `.kodehold-state`: `STATE=ACTIVE`

---

**Steps 10+** — Continue through ACTIVE → REVIEW → CLOSED as normal

Same flow as Scenario 1. The adopted project now follows the standard lifecycle from ACTIVE forward.

**Final State:**
```
Project: my-app (adopted)
State: ACTIVE → ... → CLOSED
Adopted: true
Original location: /home/user/my-app
Symlinked at: workspaces/my-app/
Steps: 9+ (adoption phase) + standard lifecycle
Teams involved: All 8
```

---

## 9. Cross-Reference Matrix

### Team Participation by Scenario

| Team | Scenario 1 (New) | Scenario 2 (Bug Fix) | Scenario 3 (Reopen) | Scenario 4 (Adopt) |
|------|------------------|----------------------|---------------------|---------------------|
| **Director** | All steps | Steps 2, 4, 6 | All steps | Steps 2, 3, 5, 7, 9+ |
| **Architects** | Steps 3–4, 12–13 | — | Steps 2–3, 5–6, 12–13 | Steps 3–4 |
| **Engineers** | Steps 16–17 | — | Steps 16–17 | Steps 16–17 (in ACTIVE) |
| **Testers** | Steps 20–21 | — | Steps 20–21 | Steps 20–21 (in ACTIVE) |
| **Reviewers** | Steps 7–8, 14–15, 18–19, 22–23 | — | Steps 7–8, 14–15, 18–19, 22–23 | Steps 5–6 |
| **Scribes** | Steps 5–6, 26, 29 | Steps 4–5 | Steps 26, 29 | (in ACTIVE) |
| **FLS** | Step 25 (vote) | Steps 2–3 | Step 25 (vote) | — |
| **Second Opinion** | Steps 9–10 | — | Steps 9–10 | Steps 7–8 |
| **User** | Steps 2, 11, 27 | Step 1 | Step 1 | Step 1 |

### Marker Creation and Consumption by Scenario

| Marker | Scenario 1 | Scenario 2 | Scenario 3 | Scenario 4 |
|--------|-----------|-----------|-----------|-----------|
| `.design_reviewed` | Created: Step 8, Consumed: Step 11 | — | Created: Step 8, Consumed: Step 11 | Created: Step 6, Consumed: Step 9 |
| `.second_opinion_done` | Created: Step 10, Consumed: Step 11 | — | Created: Step 10, Consumed: Step 11 | Created: Step 8, Consumed: Step 9 |
| `.design_review_v2` | Created: Step 13, Consumed: Step 15 | — | Created: Step 13, Consumed: Step 15 | — |
| `.code_reviewed` | Created: Step 19, Consumed: Step 24 | — | Created: Step 19, Consumed: Step 24 | — |
| `.testers_done` | Created: Step 21, Consumed: Step 24 | — | Created: Step 21, Consumed: Step 24 | — |
| `.impact_analysis_done` | — | — | Created: Step 3, Consumed: Step 4 | — |
| `.distill_needed` | Created: Step 28, Consumed: Step 29 | — | Created: Step 26 | — |

---

## 10. Marker Lifecycle

### Complete Marker Flow

```
INIT Phase:
  ┌─────────────────────────────┐
  │ .design_reviewed            │──→ Created by Reviewers (design review)
  │ .second_opinion_done        │──→ Created by Second Opinion
  └──────────┬──────────────────┘
             │ Gate: INIT → ACTIVE
             ▼
         CLEANED by gate.sh

ACTIVE Phase:
  ┌─────────────────────────────┐
  │ .design_review_v2           │──→ Created by Architects (detailed design)
  │ .code_reviewed              │──→ Created by Reviewers (code review)
  │ .testers_done               │──→ Created by Testers (tests complete)
  └──────────┬──────────────────┘
             │ Gate: ACTIVE → REVIEW
             ▼
         CLEANED by gate.sh

REVIEW Phase:
  (no markers — Team Meeting is the gate)

REVIEW → CLOSED:
  ┌─────────────────────────────┐
  │ .distill_needed             │──→ Created by gate.sh
  └──────────┬──────────────────┘
             │ Scribes: memoir distillation
             ▼
         REMOVED by Scribes

CLOSED → REOPEN:
  ┌─────────────────────────────┐
  │ .impact_analysis_done       │──→ Created by Architects
  └──────────┬──────────────────┘
             │ Gate: CLOSED → REOPEN
             ▼
         CLEANED by gate.sh
```

### Marker Dependency Chain

```
.design_reviewed ─┐
                  ├─→ Gate 0 (INIT→ACTIVE) ─→ .design_review_v2
.second_opinion ──┘                              │
                                                 ├─→ Gate 2 (ACTIVE→REVIEW)
.code_reviewed ────┐                             │
.testers_done ─────┘                             │
                                                 ▼
                                          Team Meeting
                                                 │
                                                 ▼
                                        REVIEW→CLOSED
                                                 │
                                                 ▼
                                        .distill_needed
                                                 │
                                                 ▼
                                    Scribes: memoir distillation
```

---

## Appendix: State Transition Summary

| Transition | Trigger | Gate Script | Markers Required | User Confirmation |
|-----------|---------|------------|-----------------|-------------------|
| INIT → ACTIVE | Design approved | `gate.sh --transition INIT_TO_ACTIVE` | `.design_reviewed`, `.second_opinion_done` | Yes |
| ACTIVE → REVIEW | Tests pass, code reviewed | `gate.sh --transition ACTIVE_TO_REVIEW` | `.code_reviewed`, `.testers_done` | No |
| REVIEW → CLOSED | Team Meeting 6/6 | `gate.sh --transition REVIEW_TO_CLOSED` | None (ship.sh runs) | Yes |
| CLOSED → REOPEN | Feature request | `gate.sh --transition CLOSED_TO_REOPEN` | `.impact_analysis_done` | No |
| REOPEN → ACTIVE | Design updated | `gate.sh --transition REOPEN_TO_ACTIVE` | `.design_reviewed`, `.second_opinion_done` | No |

---

*Document generated for KodeHold lifecycle simulation. All scenarios use the fictional `taskflow-api` project.*
