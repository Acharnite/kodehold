# KodeHold Safety Policy

## Denylist Paths

The following paths must NEVER be edited by autonomous loops without explicit human approval:

- `.env`, `.env.*`
- `auth/`, `secrets/`, `credentials/`
- `config/agents.yaml` — agent definitions
- `opencode.json` — opencode configuration
- `.github/workflows/*` — CI/CD pipeline definitions

## Auto-Merge Policy

- L1 loops must NEVER merge or push.
- All changes go through a PR with human review.
- Dependabot PRs require human merge approval.

## MCP Scopes

| Tool | Allowed L1 | Allowed L2 |
|------|-----------|------------|
| GitHub read (PRs, issues, CI) | ✅ Read-only | ✅ Read + comment |
| GitHub write (merge, push) | ❌ Denied | ❌ Denied (Human only) |
| bash (git, npm) | ✅ Read-only commands | ✅ Limited write |
| memory (opencode-mem) | ✅ Read + write reports | ✅ Read + write reports |

## Human Escalation

If a loop encounters any of these, it MUST stop and signal the human:

1. `.loop_error` marker exists from a prior failed run
2. Same issue detected 3+ consecutive runs without progress
3. Path in denylist needs modification
4. Token budget exceeded
5. Merge conflict on a critical PR

## Least-Privilege Tool Scope

Per ADR-0056, agents operate with minimal tool access:

| Agent | Write Tools | Read Tools | Bash |
|-------|------------|------------|------|
| Director | None | All | All |
| Engineers | write, edit, create | All | All |
| Scribes | write, edit | All | All |
| Reviewers | None | All (read-only) | read-only |
| FLS | write, edit | All | All |
| Testers | None | All | test-only |
| All loops (L1) | None | read, grep, glob | read-only |

## Circuit Breaker (Stall Detection)

- Max 3 failed attempts per issue before escalation.
- Track attempts in `loop-run-log.md`.
- If same finding appears in 3 consecutive reports with no change → escalate.
