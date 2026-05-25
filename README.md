# KodeHold

**AI-powered coding orchestrator** — conscious team-based software engineering with structured design documents, persistent memory, lifecycle gates, and multi-LLM support.

KodeHold simulates a disciplined software organization where specialized AI agents collaborate under a Director to produce high-quality code. Every project is centered on a living design document that is continuously reviewed and updated throughout development.

## Philosophy

- **Design-first** — no code without an approved design
- **Separation of concerns** — distinct teams for design, implementation, review, testing, and memory
- **Token-conscious** — every operation evaluated for token cost
- **Persistent memory** — full context preserved across sessions via ICM
- **Traceable decisions** — all architecture decisions recorded as ADRs
- **LLM-agnostic** — Ollama primary, second-opinion cross-check supported
- **Gate-driven lifecycle** — every state transition validated by automated gates

## Architecture

```
Director                        ← orchestrator, gates, delegation
├── Architects   — design documents, ADRs, technical decisions
├── Engineers    — implementation, refactoring, bug fixes
├── Reviewers    — code review, design review, second opinion
├── Testers      — testing, verification, regression
└── Scribes      — ICM memory, documentation, knowledge extraction
```

## Lifecycle

```
INIT → ACTIVE → REVIEW → CLOSED ↔ REOPEN
```

Each transition runs automated gates via `scripts/gate.sh`. Agents check state before work and refuse if in the wrong phase.

## Workspaces

Managed projects live in `workspaces/<name>/`:
- `bash scripts/workspace.sh init <name>` — create a new project
- `bash scripts/workspace.sh list` — list all projects with state
- `bash scripts/workspace.sh gate <name> <transition>` — run gate on a project
- `bash scripts/workspace.sh deploy-ready <name>` — check if CLOSED

## Quick Start

```bash
# Prerequisites: OpenCode, ICM, RTK — all installed
git clone https://github.com/Acharnite/kodehold.git
cd kodehold
opencode --agent director
```

## Documentation

| Path | Description |
|------|-------------|
| `docs/design/README.md` | Main design document — full architecture, lifecycle, constraints |
| `docs/adr/` | Architecture Decision Records (ADR-0001 through ADR-0008) |
| `.opencode/agents/director.md` | Director agent — full orchestrator protocol |
| `.opencode/agents/` | Team subagent definitions (5 teams) |
| `scripts/gate.sh` | Lifecycle gate automation |
| `scripts/workspace.sh` | Workspace project management |
| `scripts/ship.sh` | Shipping gate automation |

## Requirements

- **OpenCode** — agent framework
- **ICM** v0.10+ — persistent memory (`cargo install icm`)
- **RTK** v0.40+ — token-optimized CLI (`pip install rtk`)
- **Ollama** — local LLM inference

All configs and functions are in English for token efficiency.
