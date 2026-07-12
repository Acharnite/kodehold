---
type: decision
project: krypto-agent
concepts: vllm, ollama, llm, embedding, gpu, vram, inference
created: 2026-07-09
---

# ADR-0053: Replace Ollama with vLLM for Concurrent LLM + Embedding Serving

## Decision Summary

**Status:** Accepted (2026-07-09)

**Problem:** Ollama cannot run LLM inference (qwen3.5:9b) and embedding (bge-m3) concurrently due to VRAM limitations on GTX 1080Ti (11GB).

**Solution:** Dual vLLM instance architecture:
- **LLM Instance** (port 8000): qwen3.5:9b for text generation
- **Embedding Instance** (port 8001): bge-m3 for embeddings

**Key Benefits:**
- Concurrent serving without VRAM exhaustion
- OpenAI-compatible API (minimal code changes)
- Better throughput with PagedAttention
- Isolated failure domains

**Hardware:** GTX 1080Ti (Pascal, 11GB VRAM)
- LLM: 5.5-7.5GB + Embedding: 1.5GB + Overhead: 0.5GB = 7.5-8.5GB ≤ 11GB ✓

**Implementation:**
1. `pip install vllm`
2. LLM: `vllm serve qwen3.5:9b --port 8000 --gpu-memory-utilization 0.7`
3. Embedding: `vllm serve bge-m3 --port 8001 --gpu-memory-utilization 0.2`
4. Update config.yaml endpoints
5. Add health checks

**Alternatives Rejected:**
- Ollama model swapping (latency)
- Python sentence-transformers (dependency)
- Cloud embedding API (cost/latency)

**Review Notes:**
- Hardware model corrected (GTX 1080Ti, not RTX 2080 Ti)
- VRAM calculations verified for GTX 1080Ti
- Test count aligned (746 tests)
- Ollama API endpoint corrected (POST /api/embed)
- ADR numbering: ADR-0053 (ADR-0020 taken by Hierarchical Memory)

**Files:**
- ADR: `docs/adr/ADR-0053-replace-ollama-with-vllm.md`
- Design Doc: `docs/design/README.md` Section 8.1
- VERSION.md: v1.19.0 entry
- CHANGES.md: v1.19.0 changelog
