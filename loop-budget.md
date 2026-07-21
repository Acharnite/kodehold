# Loop Budget — KodeHold

> Primary loops: **Daily Triage, PR Babysitter, Drift Detection** (Phase 2, L1)

## Daily limits

| Loop | Max runs/day | Max tokens/day | Max sub-agent spawns/run |
|------|--------------|----------------|--------------------------|
| Daily Triage | 1 | 100k | 0 (L1) |
| PR Babysitter | 3 | 150k | 0 (L1) |
| Drift Detection | 1 (weekly) | 100k | 0 (L1) |

## On budget exceed

1. Create `.loop_budget_exceeded` marker file
2. Append event to `loop-run-log.md`
3. Switch to report-only for rest of day

## Kill switch

- Marker file `.loop_pause_all` halts all loops immediately
- Resume only after human removes the marker

## Estimate spend

```bash
npx @cobusgreyling/loop-cost --pattern daily-triage
npx @cobusgreyling/loop-cost --pattern pr-babysitter
npx @cobusgreyling/loop-cost --pattern ci-sweeper
```
