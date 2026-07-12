---
type: pattern
project: krypto-agent
concepts: concurrency, caching, api-design
created: 2026-07-03
---

# Shared Price Cache for Concurrent API Endpoints

## Problem
When multiple API endpoints fetch overlapping market data concurrently (e.g., `/api/positions` and `/api/portfolio` both need current prices), responses can race — each endpoint's response overwrites shared state, causing "value hopping" or stale data display.

## Solution
1. **Shared cache with threading lock**: One price cache object protected by `threading.Lock()` ensures only one request fetches prices at a time
2. **Deduplicate fetching**: Source all price-dependent values from a single helper function (`_with_prices`) instead of each endpoint doing its own CCXT calls
3. **No cross-population**: Never let one endpoint populate data meant for another — each endpoint returns only its own domain data

## Implementation
```python
from threading import Lock

class PriceCache:
    def __init__(self):
        self._lock = Lock()
        self._prices = {}
        self._last_fetch = 0
```

## Lesson
Race conditions in API servers aren't always about shared mutable state — they can also be about **timing of concurrent HTTP responses**. A shared cache with proper locking is simpler and more reliable than trying to coordinate endpoint execution order.
