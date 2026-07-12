---
type: decision
project: krypto-agent
concepts: ADR, review, vLLM, Ollama, embedding model, GPU hardware
created: 2026-07-09
---

# ADR-0020 Review Fixes

## Request
Fix 5 issues identified in ADR-0020 review: GPU model discrepancy, embedding model mismatch, test count incorrect, Ollama API endpoint, and unourced performance claims.

## Outcome
ADR-0020 (`docs/adr/ADR-0020-replace-ollama-with-vllm.md`) updated with all fixes:

1. **GPU Model Discrepancy (Line 65)**: Changed "RTX 2080 Ti" → "GTX 1080Ti"
2. **Embedding Model Mismatch**: Changed all "bge-m3" references to "nomic-embed-text" (matching config.yaml authoritative source)
   - `BAAI/bge-m3` → `nomic-ai/nomic-embed-text-v1`
   - `bge-m3:latest` → `nomic-embed-text:latest`
3. **Test Count Incorrect (Line 229)**: Changed "370" → "746"
4. **Ollama API Endpoint (Line 135)**: Changed `/api/embeddings` → `/api/embed`
5. **Performance Claims (Lines 68, 156, 157)**: Added "(claimed by vLLM project)" to performance assertions

## Changes Made
- 18 lines modified across the ADR
- All "bge-m3" references updated to "nomic-embed-text"
- GPU model corrected to match actual hardware
- Test count updated to match actual test suite
- API endpoint corrected to match current Ollama API
- Performance claims now properly attributed

## Files Modified
- `/home/kiffer/project/krypto-agent/docs/adr/ADR-0020-replace-ollama-with-vllm.md`

## Backup
- Original file backed up as `ADR-0020-replace-ollama-with-vllm.md.backup`

## Validation
- All changes verified via diff comparison
- ADR now aligns with config.yaml (authoritative source for embedding model)
- ADR now reflects actual hardware and test count
- Performance claims properly sourced