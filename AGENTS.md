# KodeHold Director

Full agent definition: `.opencode/agents/director.md`

## Delegation & Protocol

All delegation rules, triage-check, state transitions, gates, shipping, and workspace management are defined in the full agent definition:

→ **`.opencode/agents/director.md`** — includes:
- Trigger → Team mapping & delegation patterns
- Triage-Check Protocol
- Lifecycle states & transition gates
- Shipping Gate (8-step process)
- Workspace management commands
- Context window & session management
- Token budget protocol

## Design Principles & Directives

### Token-Optimized Loading
**Files loaded often must be lean and precise; files loaded less must be descriptive and precise.**

Loaded every session (keep lean, reference-heavy):
- `AGENTS.md` — top-level instructions, Quick Reference, global directives
- `director.md` — agent definition, lean delegation protocol, skill references
- `.opencode/agents/*.md` — team-specific instructions (loaded on delegation)

Loaded on demand (be descriptive):
- `.opencode/skills/*/SKILL.md` — loaded via `skill()` call
- `docs/design/README.md`, `docs/adr/*.md` — loaded via read/search
- `config/tasks.yaml` — loaded during CI/validation only

### Design-First
No implementation work begins without an approved design document. Every project starts with and revolves around a living design doc (`docs/design/README.md`). Architects create the design, Reviewers approve it, and only then does implementation begin.

### Separation of Concerns
Distinct teams handle design, implementation, review, testing, and memory — no single agent performs all roles. The Director delegates everything via the Task tool and NEVER implements directly. Scribes handles ALL documentation — no other team writes or updates docs.

### LLM-Agnostic
KodeHold works with any LLM provider. Ollama is the primary provider, but the system supports switching models per team and requesting second opinions from different models (via `second-opinion` subagent) to avoid same-model bias.

## KodeHold Quick Reference

### Architecture
- Design doc: `docs/design/README.md`
- Agent configs: `.opencode/agents/`
- ADRs: `docs/adr/ADR-NNNN-<slug>.md`

### Commands
- Run tests: `pytest tests/ -x -v`
- Lint: `ruff check .` (Python), `eslint .` (JS/TS)
- Gate: `python3 scripts/gate.py --transition <FROM>_TO_<TO>`
- State: `.kodehold-state`

### Conventions
- Agent files: `.opencode/agents/<team>.md`
- Design doc: `docs/design/README.md`
- Workspace projects: `workspaces/<name>/`

### Teams
- Architects — Design authority, ADRs, tech decisions
- Engineers — Implementation, refactoring, bugfixes
- Testers — Verification, test suites, edge cases
- Reviewers — Code/design review, gate validation
- Scribes — ALL documentation, memory, changelog
- FLS — Triage, hotfix, escalation
- Second Opinion — Cross-model validation

### Coding
- **The Ladder (ADR-0049)** — before writing code: YAGNI → stdlib → platform → existing deps → one line → minimum code. Boring over clever, deletion over addition. `ponytail:` comments for intentional shortcuts. NOT lazy about: security, validation, error handling, accessibility.

### Lifecycle
- INIT → ACTIVE → REVIEW → CLOSED → REOPEN → ACTIVE
- INIT — Design doc created, ADRs drafted, project scoped
- ACTIVE — Implementation and testing
- REVIEW — Final review and verification
- CLOSED — Project complete, archived
- REOPEN — Impact analysis, design update, new ADRs

### Access
- RAG tools: `search_semantic`, `find_usages`, `get_file_skeleton`, `describe_image`
- Design doc: `docs/design/README.md`
- Memory: `.opencode/memory/`
