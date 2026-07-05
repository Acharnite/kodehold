---
type: checkpoint
project: krypto-agent
state: ACTIVE
created: 2026-07-04
---

# Session Checkpoint: SL/TP Execution + Bugfix Marathon

- **Completed**: Stop-loss/take-profit automated execution, 4 bug fixes, 2 config fixes, data reset
- **In-progress**: N/A — session concluded
- **Decisions**: See below
- **Files**: 8+ files modified across 4 directories
- **Teams**: Engineers (direct), Scribes (this checkpoint)
- **Blockers**: None
- **Carry-forward**: N/A — fresh clean state

## Features

### SL/TP Execution (issue #12)
- Automatic stop-loss and take-profit monitoring per position
- When `current_price <= stop_loss` → auto-sell at market (🔴)
- When `current_price >= take_profit` → auto-sell at market (🟢)
- Status column in positions table with colored indicators (🔴/🟡/🟢)
- SL/TP checked every daemon cycle alongside decision engine
- Separate handler in daemon cycle to isolate from decision logic

## Bug Fixes

### 1. OHLCV Cache Bug — Stale Entries Never Deleted
- `cache_market_data()` had a `commit()` call (was present), but stale cache entries weren't being cleaned properly
- Old entries with matching `(pair, interval)` but older TTL were never evicted
- **Fix**: Delete stale entries before inserting new ones — cache TTL now works correctly

### 2. NewsAnalyzer Cache Bug — Per-Instance Freshness
- `_cache_time` was a float assigned in `__init__`: `self._cache_time = time.time()` — immutable primitive copied per instance
- Every NewsAnalyzer instance started with `_cache_time = now`, so first news fetch always appeared fresh, but cross-instance usage caused cache misses
- **Fix**: Embed cache timestamps inside the mutable `_cache` dict instead of a standalone float

### 3. Server Startup Hang — Blocking LLM Call
- `/api/news` endpoint called `llm.summarize()` directly in the async event loop (synchronous Ollama call)
- Blocked ALL other requests during summarization (took 5-10s per call)
- **Fix**: Wrapped in `asyncio.to_thread()` + `asyncio.wait_for(timeout=30)` — non-blocking summarization

### 4. SL Rounding Bug — Low-Priced Coins
- `round(price - sl_distance, 2)` for DOGE (~0.16), ARPA (~0.07) gave SL = entry price (difference rounded to zero)
- **Fix**: Minimum 0.5% distance from entry + 4 decimal places for low-priced coins (< 1.0)

### 5. SL/TP Duplicate Trades
- SL/TP handler called `save_trade()` directly, but `executor.execute()` also saves the trade
- Result: duplicate trade rows in DB
- **Fix**: Removed duplicate `save_trade()` call — executor already handles saving

## Config Fixes

### Decision Interval
- Daemon was using CLI `--interval` flag for decision cycle (default 60s)
- Config had `decision_interval_minutes: 15` but it was being ignored
- **Fix**: Daemon now reads `decision_interval_minutes` from config properly

## Data Reset
- Database fully cleared (positions, trades, decisions, snapshots)
- Fresh 100€ snapshot deployed
- Clean slate for monitoring SL/TP behavior

## Key Decisions
1. **SL/TP as daemon cycle feature** — not implemented as a separate thread; integrated into existing `_run_cycle()` after decision logic
2. **Cache timestamps in mutable dict** — float primitives in `__init__` cause cross-instance freshness bugs. Always embed timestamps inside mutable containers
3. **Minimum SL distance** — for low-priced coins, absolute rounding kills precision. Use percentage-based minimums + extra decimal places
4. **Executor saves trades** — `PaperExecutor.execute()` already handles DB persistence. Callers must NOT also call `save_trade()`

## TokenUsage
- Not available (session used OpenCode directly, not KodeHold delegation tracking)
