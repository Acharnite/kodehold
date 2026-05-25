# KodeHold Protocol — Shared Reference

## RTK Mandatory

All CLI commands must use RTK for token-efficient output.

```bash
rtk ls           # list files
rtk read <file>  # read files
rtk grep <pat>   # search content
rtk tree         # show tree
rtk git status   # git status
rtk git diff     # git diff
rtk git log      # git log
```

## Token Budgets (per operation)

| Operation | Max Tokens |
|-----------|-----------|
| Context load | 8k |
| Code generation | 12k |
| Code review | 8k |
| Test generation | 8k |
| Documentation | 4k |
| Second opinion | 6k |

## Light Mode (32k context)

When `KODEHOLD_LIGHT=1` or model context <= 32k:
- Collapse Reviewers + Testers into single Quality team
- Use ICM summaries, never full memories
- Chunk files > 100 lines
- 28k hard limit per operation
- No redundant context between messages
- English-only prompts

## Inter-Agent Communication

When work requires a different team:

```
### Suggested next agent
Agent: <team-name>
Reason: <why this team is needed>
Context: <what context to pass>
```

## ICM Topic Convention

```
kodehold-<namespace>-<qualifier>
```

Examples:
- `kodehold-project-overview`
- `kodehold-architecture-teams`
- `kodehold-principles`
- `kodehold-current-state`

## Quality Gate Checklist

Before transitioning between lifecycle states, verify:
- [ ] Design doc is current and approved
- [ ] ADRs cover all significant decisions
- [ ] Code matches design doc specs
- [ ] Tests exist and pass
- [ ] Token budget is within limits
- [ ] ICM memory is stored
