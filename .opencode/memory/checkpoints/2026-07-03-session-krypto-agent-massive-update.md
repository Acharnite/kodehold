---
type: checkpoint
project: krypto-agent
state: ACTIVE
created: 2026-07-03
---

# Session Checkpoint: Krypto-Agent Massive Update

- **Completed**: Massive cross-cutting update across LLM, news, dashboard, performance, and bug-fix domains
- **In-progress**: N/A — session concluded
- **Decisions**: See below
- **Files**: 16+ files modified across 7 directories
- **Teams**: Engineers, Testers, Scribes
- **Blockers**: None
- **Carry-forward**: N/A

## LLM & Model
- Fixed warmup to use correct `num_ctx` (4096 from config) instead of hardcoded 2048 — model was being ejected from GPU repeatedly
- Added `summarize()` method to `LLMMarketAnalyzer` for LLM-based news summarization
- Added retry logic to `_call_ollama()` — 2 retries with exponential backoff (2s, 4s) on transient failures (ConnectionError, Timeout)
- Rounded indicator values in LLM prompt — RSI/SMA/BB/ATR to 2 decimals, MACD to 4 decimals (was raw float precision)
- Confidence capped at 0.9 (90%) instead of 1.0 (100%), with -15% penalty per missing indicator (max -60%)

## News & Sentiment
- Swapped NewsAPI (24h delay, required API key) → Google News RSS → **Multi-source crypto RSS** (CoinDesk + CoinTelegraph + Decrypt)
- CryptoPanic removed (API free tier discontinued Apr 2026)
- News cache TTL made configurable via settings (`news_cache_minutes`)
- Summarization only runs on fresh news (not from cache)
- Fetches 20 headlines from 3 sources, deduplicated across feeds

## Dashboard & UI
- Fixed pair browser table alignment — root cause was Alpine.js `:style` overriding `text-align:right` (when `:style` returns a string, it replaces the entire style attribute)
- Removed `table-layout:fixed`, colgroup, overflow hacks — now uses plain `<table>` matching Current Positions pattern
- Removed `fetchStatus()` overwriting portfolio data — race condition caused values to "hop"
- Added pair screener with dropdown filter (Top 50 Volume / Top Gainers / Top Losers) + volatility column
- Tab title now shows total value + ▲/▼ trend
- Risk? column shows "✅ Pass" / "❌ Block" instead of just ✅/❌
- Added Åbnet (time ago) column to positions table
- Added Reason column to trades table (decision reasoning via JOIN on decision_id)
- Added LLM summarization + Fear & Greed to /api/news endpoint with 5-min cache
- Settings page: added max_positions, temperature, num_ctx slider, news_cache_minutes, risk checkboxes

## Performance & Caching
- OHLCV cache TTL — technical analysis now refreshes based on candle interval (1h candles = 1h cache), was stuck forever
- Ticker cache in MarketDataFetcher (30s TTL) — reduced CCXT calls
- Shared price cache between `/api/positions` and `/api/portfolio` with threading lock (prevents race condition on concurrent requests)
- Event loop reuse — long-lived daemon thread instead of creating/destroying loops per SSE event
- Reduced redundant DB reads in PaperExecutor (accepts optional positions parameter)
- Lifted market data fetcher out of per-pair loop (one fetcher per daemon cycle)
- python-dotenv auto-loads .env file — env vars always work regardless of bashrc
- Equity curve: filtered crash-fallback snapshots, deduplicated, capped at 500 points (was 2073)

## Bug Fixes
- `save_decision` type crash: added `_sanitize()` in db.py to convert dict/list to None before SQLite binding
- ZeroDivisionError in paper.py: guard against `fill_price = 0`
- Trades table: `decision_id` now populated (save decision BEFORE trade execution, pass id to executor)
- Two-stage shutdown: first ctrl+c = graceful, second within 3s = force `os._exit(1)`
- Dashboard freeze: `/api/positions` was missing `asyncio.wait_for` timeout (added 15s)
- daemon crash cleanup: cleared `.pyc` cache (was loading stale bytecode)
- Clean slate: wiped 2114 snapshot rows + all positions/trades/decisions

## Dependencies Added
- `python-dotenv>=1.0` to pyproject.toml

## Files Modified
| File | Changes |
|------|---------|
| `krypto_agent/__init__.py` | dotenv auto-load |
| `krypto_agent/analysis/llm_analyzer.py` | summarize(), retry logic, warmup fix, indicator rounding |
| `krypto_agent/analysis/news.py` | multi-RSS, CoinDesk/CoinTelegraph/Decrypt, cache TTL, news_cached flag |
| `krypto_agent/decision/engine.py` | confidence cap 0.9 |
| `krypto_agent/execution/paper.py` | decision_id param, zero fill_price guard |
| `krypto_agent/main.py` | two-stage shutdown, news summarization, confidence penalty, event loop reuse |
| `krypto_agent/storage/db.py` | get_cached_market_data returns fetched_at, OHLCV cache TTL |
| `krypto_agent/web/server.py` | shared price cache + lock, _with_prices helper, pair high/low, equity curve filter |
| `krypto_agent/web/static/index.html` | pair browser table fix, tab title, pair screener, Reason column, Åbnet column, settings additions, Risk? labels, volatility, sort/filter |
| `config.yaml` | news_cache_minutes |
| `.env.example` | updated |
| `pyproject.toml` | python-dotenv |
| `tests/` | updated for multi-feed RSS mocks, single cache key tests |

## Key Decisions
1. **Multi-RSS over NewsAPI** — CoinDesk + CoinTelegraph + Decrypt for free, specific market news (no API key needed)
2. **Alpine.js :style string bug** — `:style="'text-align:right'"` replaces entire style attribute. Fix: use object syntax `:style="{textAlign: 'right'}"` or inline CSS
3. **fetchStatus race condition** — concurrent endpoint responses overwriting portfolio state. Fix: source portfolio from single endpoint, don't cross-populate
4. **num_ctx from config** — hardcoded 2048 was causing GPU ejection. Fix: read from config setting
5. **Decision-first execution** — save decision to DB BEFORE executing trade so decision_id is available

## TokenUsage
- Not available (session used OpenCode directly, not KodeHold delegation tracking)
