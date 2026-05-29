# KodeHold Workshop Guide

A quick-start guide for onboarding teams to the KodeHold methodology.

## What is KodeHold?

KodeHold is an AI-powered coding orchestrator that simulates a disciplined software organization where specialized AI agents collaborate under a Director to produce high-quality code. It enforces design-first development, persistent memory via ICM, lifecycle gates, and multi-LLM support for traceable, token-conscious software engineering.

## The 6 Teams

| Team | Role | Key Responsibilities |
|------|------|----------------------|
| **Architects** | Design & Architecture | Create design documents, draft ADRs, evaluate technology choices |
| **Engineers** | Implementation | Write code, implement features, fix bugs, refactor |
| **Testers** | Quality Assurance | Write tests, verify functionality, regression testing, performance |
| **Reviewers** | Code & Design Review | Code review, design review, enforce standards, second opinions |
| **Scribes** | Memory & Documentation | ICM memory management, documentation, changelog, knowledge extraction |
| **FLS** | Front Line Support | Triage, hotfix, escalation, support tasks |

## Lifecycle States

```
INIT → ACTIVE → REVIEW → CLOSED ↔ REOPEN
```

| State | What Happens |
|-------|--------------|
| **INIT** | Design doc created, ADRs drafted, project scoped |
| **ACTIVE** | Implementation phase: Engineers → Testers → Reviewers (sequential) |
| **REVIEW** | Final gate — Team Meeting reviews all work across all 6 teams |
| **CLOSED** | Complete, context stored in ICM |
| **REOPEN** | Resurrected for new features or bug fixes |

Each transition runs automated gates via `scripts/gate.sh`. Agents check state before work and refuse if in the wrong phase.

## Starting a Project

### 1. Initialize Workspace

```bash
# Create a new project
bash scripts/workspace.sh init <project-name>

# List all projects
bash scripts/workspace.sh list
```

### 2. Design Phase (INIT)

The Director delegates to **Architects** to create:
- Design document (`docs/design/README.md`)
- Architecture Decision Records (ADRs)

### 3. Gate to ACTIVE

Once design is reviewed and approved:
```bash
bash scripts/workspace.sh gate <project-name> transition INIT_TO_ACTIVE
```

Requires: `.design_reviewed` marker + user confirmation.

## How Delegation Works

The Director orchestrates all work through the **Task tool**:

```
User Request → Director → Task Tool → Team Agent → Result → Director
```

### Delegation Table

| Trigger | Team(s) | Sequence |
|---------|---------|----------|
| Design/ADR | Architects → Scribes | Post-task documentation |
| Implementation | Engineers → Scribes | Post-task documentation |
| Investigate/Debug | Engineers or FLS → Scribes | Root cause first, then documentation |
| Test | Testers → Scribes | Must finish before review |
| Review | Reviewers → Scribes | Must run after tests pass |
| Memory/Docs | Scribes | — |
| Support/Hotfix | FLS → Scribes | Post-task documentation |

**Key Rule:** Scribes handles ALL documentation post-task. Teams READ design docs before work but don't UPDATE them.

## Quality Gates

### State Transition Gates

Every transition is validated by `scripts/gate.sh`:

```bash
# Check current state
bash scripts/gate.sh --status

# Run gate for transition
bash scripts/gate.sh --transition <FROM>_TO_<TO>
```

### Gate Markers

| Gate | Required Marker | Created By |
|------|-----------------|------------|
| INIT → ACTIVE | `.design_reviewed` + user confirmation | Reviewers |
| ACTIVE → REVIEW | `.testers_done` | Testers |
| REVIEW → CLOSED | Team Meeting (all 6 teams) | — |
| CLOSED → REOPEN | `.impact_analysis_done` | Architects |

### Shipping Gate (8 Steps)

Run `scripts/ship.sh` for automated checks (steps 1-7). Step 0 (Team Meeting) is manual.

## ICM Memory System

ICM (Infinite Context Memory) provides persistent memory across sessions.

### Key Concepts

- **Topics**: Namespaced storage (e.g., `kodehold-<project>-<topic>`)
- **Importance**: Critical (never forgotten), High (slow decay), Medium, Low (fast decay)
- **Hybrid Search**: 70% vector + 30% BM25 for intelligent retrieval
- **Auto-Dedup**: Prevents duplicate memories (>85% similarity)

### Common Operations

```bash
# Store a memory
icm_memory_store -t "kodehold-<project>-decisions" -i high -k "architecture" -c "Decision content"

# Recall memories
icm_memory_recall -t "kodehold-<project>" -i critical high

# Search memoirs
icm_memoir_search "kodehold-<team>" "<query>"
```

### Session Checkpoints

Store context before transitions:
```bash
icm_memory_store -t "kodehold-<project>-session-checkpoint" -i critical -k "checkpoint,session"
```

## Getting Started Checklist

### Prerequisites
- [ ] OpenCode installed
- [ ] ICM v0.10+ installed (`cargo install icm`)
- [ ] RTK v0.40+ installed (`pip install rtk`)
- [ ] LLM provider configured (Ollama or other)

### First Project Steps
1. Clone repository and run `opencode`
2. Initialize workspace: `bash scripts/workspace.sh init my-project`
3. Read design doc, delegate to Architects
4. Review and approve design
5. Gate to ACTIVE: `bash scripts/workspace.sh gate my-project transition INIT_TO_ACTIVE`
6. Delegate implementation → testing → review
7. Gate to REVIEW, then CLOSED
8. Store final context in ICM

### Daily Workflow
1. Check state: `bash scripts/gate.sh --status`
2. Read design doc before any work
3. Delegate tasks via Director, let Scribes handle docs
4. Run gates before state transitions

---

## Key Commands

```bash
# Workspace
bash scripts/workspace.sh init <name> | list | state <name> | gate <name> <transition>

# Gates
bash scripts/gate.sh --status | --transition <FROM>_TO_<TO>

# Shipping
bash scripts/ship.sh

# ICM
icm_memory_store -t "<topic>" -i <importance> -k "<keywords>" -c "<content>"
icm_memory_recall -t "<topic>" -i <importance>
icm_memoir_search "<memoir>" "<query>"
```

**Version:** 1.0  
**Last Updated:** 2026-05-29  
**Maintained by:** Scribes Team