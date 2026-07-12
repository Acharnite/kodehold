---
type: bug
concepts: equity-curve, stale-snapshots, live-prices
date: 2026-07-10
---

# Equity Curve Stale Max Value

## Symptom
User reported total_value is 93.59€ but equity curve shows max: 79.60€.

## Root Cause
The equity curve in the dashboard only used historical snapshots stored in the database. These snapshots are saved by the daemon/pipeline when they run. When the daemon is idle or stopped, no new snapshots are saved, so the chart's max value reflects the last snapshot's total_value, not the current live portfolio value.

The web API's `api_portfolio()` correctly computes the live total_value (cash + positions_value using live prices) for the overview, but the equity_curve data only came from the database snapshots.

## Fix
Appended a live data point with current prices at the end of the equity curve when there is existing history. This ensures the chart always reflects the current portfolio value as the latest point.

File changed: `krypto_agent/web/routes.py`
Line: After unrealized P&L calculation (around line 585)

## Evidence
- Pre-existing snapshot values: ~79.59€ (from database)
- Live total_value: 93.59€ (from API overview)
- After fix: equity curve includes live snapshot at ~93.59€

## Regression test
- All 34 relevant route tests pass (1 pre-existing failure excluded)
- Empty-state test still passes (no live snapshot added when no history)

## Status: DONE