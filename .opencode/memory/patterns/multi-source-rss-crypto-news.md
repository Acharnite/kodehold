---
type: architecture
project: krypto-agent
concepts: rss, news, data-sourcing
created: 2026-07-03
---

# Multi-Source RSS for Crypto News

## Architecture
Instead of requiring paid API keys (NewsAPI, CryptoPanic), use **free RSS feeds** from major crypto media:

| Source | Feed URL | Notes |
|--------|----------|-------|
| CoinDesk | `https://www.coindesk.com/arc/outboundfeeds/rss/` | Reliable, market-focused |
| CoinTelegraph | `https://cointelegraph.com/rss` | Good technical coverage |
| Decrypt | `https://decrypt.co/feed` | Educational, beginner-friendly |

## Implementation Details
- Fetch ~20 headlines from each source
- Deduplicate across feeds by normalized title
- Cache with configurable TTL (`news_cache_minutes` in settings)
- LLM summarization only on fresh news (not cached)
- Each source has a minimal parse function (title + link + published)

## Why Not...
- **NewsAPI**: 24h delay on free tier, requires API key
- **CryptoPanic**: Free API tier discontinued April 2026
- **Google News RSS**: Too general/political, not market-specific

## Lesson
Always check if RSS feeds can replace paid API endpoints. Three niche RSS feeds often beat one general API — they're free, have no rate limits (within reason), and provide more specific content.
