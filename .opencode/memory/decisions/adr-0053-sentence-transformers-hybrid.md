---
type: decision
project: krypto-agent
concepts: embeddings, sentence-transformers, bge-m3, ollama, hybrid-architecture
created: 2026-07-09
---

# ADR-0053: Hybrid Embedding Strategy

## Decision
Use **sentence-transformers on CPU** for embeddings (bge-m3), keep **Ollama for LLM inference** (qwen3.5:9b).

## Rationale
- bge-m3 uses XLMRobertaModel architecture (encoder-only, Transformers-compatible)
- ~567M parameters, fast enough on CPU (<100ms for short texts)
- Zero VRAM consumption — leaves full GPU for LLM
- No Ollama blocking — embedding requests served independently
- Simple setup: `pip install sentence-transformers`

## Rejected Alternatives
- vLLM dual-instance: Overkill for embeddings, adds process management complexity
- Ollama model swapping: Adds latency, not suitable for concurrent requests
- Cloud embedding API: Adds network latency, cost, and dependency

## Files Updated
- `docs/adr/ADR-0053-replace-ollama-with-vllm.md` — Full ADR rewrite
- `docs/adr/README.md` — ADR index updated
- `docs/design/README.md` — Section 8.1 updated, changelog entry added
