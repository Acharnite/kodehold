# Loop Configuration — KodeHold

## Active Loops

| Pattern | Cadence | Status | Command |
|---------|---------|--------|---------|
| Daily Triage | Weekdays 08:00 | L1 report-only | `scripts/loop-run.sh daily-triage "..."` via crontab |
| PR Babysitter | Weekdays 8/12/16 | L1 report-only | `scripts/loop-run.sh pr-babysitter "..."` via crontab |
| Drift Detection | Sunday 10:00 | L1 report-only | `scripts/loop-run.sh drift-detection "..."` via crontab |

## Human Gates

- No auto-fix until L2 (Phase 3 complete).
- All high-risk paths require human review (see docs/safety.md denylist).
- On `.loop_error` marker: FLS triages within 24h.

## Worktrees

- N/A for Phase 2 (L1 report-only).
- Phase 3 will introduce worktree isolation per ADR-0058 P3.1.

## Connectors (MCP)

- MCP optional for L1 report-only loops.
- GitHub MCP is connected for PR/CI reads only.

## Budget

- See `loop-budget.md` for full caps.
- If token spend hits 80% of daily cap → report-only mode.
- Kill switch: `.loop_pause_all` marker file.

## Links

- Budget: [loop-budget.md](loop-budget.md)
- Constraints: [loop-constraints.md](loop-constraints.md)
- Safety: [docs/safety.md](docs/safety.md)
- State: [STATE.md](STATE.md)
- Run log: [loop-run-log.md](loop-run-log.md)
- ADR: [ADR-0058](docs/adr/ADR-0058-loop-engineering-integration.md)
