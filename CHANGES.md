# Changelog

## 0.1.0 — 2026-05-25

### Added
- Design document (`docs/design/README.md`) — full architecture, team structure, lifecycle
- 8 Architecture Decision Records covering all design constraints:
  - ADR-0001: Foundation and principles
  - ADR-0002: Director + 5 teams (Architects, Engineers, Reviewers, Testers, Scribes)
  - ADR-0003: Design document lifecycle with review gates
  - ADR-0004: ICM and RTK integration strategy
  - ADR-0005: LLM support with Ollama and light mode (32k context)
  - ADR-0006: Second opinion protocol for cross-model validation
  - ADR-0007: Token optimization strategy (English-only, tiered loading, budgets)
  - ADR-0008: Project lifecycle with reopen and archive protocol
- ADR index (`docs/adr/README.md`)
- `.gitignore` excluding `.icm/` directory
- Top-level README, VERSION, TODO, CHANGES
- GitHub repository initialized at `github.com/Acharnite/kodehold`
- ICM persistent memory store initialized
- Director orchestrator (`AGENTS.md`) with lifecycle states, quality gates, token budgets, ICM protocol, second opinion triggers
- `opencode.json`: Ollama provider (qwen3:8b-opencode), project permissions
- 5 team subagents (`.opencode/agents/`): Architects, Engineers, Reviewers, Testers, Scribes
  - Each with YAML frontmatter, responsibilities, workflow, constraints
- Shared protocol reference (`.opencode/references/kodehold-protocol.md`)
- Test suite: 10 tests across smoke, init, and integration
- CI workflow (`.github/workflows/kodehold-ci.yml`)
- Shipping gate protocol (8-step process in AGENTS.md + `scripts/ship.sh`)
