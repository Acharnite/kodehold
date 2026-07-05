---
type: fix
project: krypto-agent
concepts: bugs, llm-warmup, hard-shutdown, dashboard-freeze
created: 2026-07-03
status: fixed
tests: 245/245 passing
---

# Three krypto-agent Bug Fixes (v0.1.1)

## Fix 1: LLM Warmup
- **Files:** `krypto_agent/analysis/llm_analyzer.py` + `krypto_agent/main.py`
- Added `warmup()` to `LLMMarketAnalyzer` — sends a dummy prompt (`"Respond with only the word OK."`) with 120s timeout and `keep_alive: 30m` to force Ollama model loading into GPU memory before the daemon cycle starts.
- Called in `cmd_run()` after `ensure_model()` in daemon mode (not dry-run).
- Non-blocking — if warmup fails, daemon continues normally (model loads on first cycle instead).

## Fix 2: Hard Shutdown (ctrl+c 2x)
- **File:** `krypto_agent/main.py`
- **First SIGINT:** Graceful shutdown — clears `_daemon_running`, completes current cycle, prints "tryk Ctrl+C igen inden for 3 sekunder for force kill".
- **Second SIGINT within 3 seconds:** Force `os._exit(1)` — defensively releases `_cycle_lock` (try/except RuntimeError).
- **SIGTERM:** Always graceful (existing behavior).
- Added `_shutdown_count` and `_SHUTDOWN_WINDOW` globals.
- Test fixture updated to reset `_shutdown_count = 0.0` between tests.

## Fix 3: Dashboard Freeze at Startup
- **File:** `krypto_agent/web/server.py`
- **`api_portfolio`:** `_fetch_live_prices()` wrapped in `asyncio.wait_for(..., timeout=15.0)` — falls back to cached `_last_positions_value` on timeout/error.
- **`api_available_pairs`:** `_fetch_pairs()` (calls `exchange.load_markets()`) wrapped in `asyncio.wait_for(..., timeout=15.0)` — returns stale cache on timeout/error.

## Tests
- `pytest tests/ -x -v`: **All 245 tests pass**.
- Committed and pushed.

## Lessons
1. **LLM cold-start latency** — Ollama models loaded on first inference call. Always explicitly warm up in daemon mode to avoid first-cycle delays. Use `keep_alive` to prevent model unloading between cycles.
2. **Two-stage shutdown** — users expect ctrl+c to "just kill it". A force-exit window after graceful shutdown prevents frustration without compromising data integrity.
3. **Async endpoint hardening** — any endpoint calling external APIs (exchange, network) needs a timeout wrapper. `asyncio.wait_for` is the standard Python approach. Always provide a stale-cache fallback.
