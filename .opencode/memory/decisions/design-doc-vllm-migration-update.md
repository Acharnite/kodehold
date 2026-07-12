---
type: decision
project: kodehold
concepts: design-doc, vllm, ollama, infrastructure, llm-support
created: 2026-07-09
---

# Design Doc Updated: vLLM Migration in Section 8.1

## What Changed
Updated `docs/design/README.md` Section 8.1 ("Bring Your Own Model") to document the vLLM migration decision:
- Ollama and vLLM both documented as local inference providers
- vLLM recommended for new deployments
- Concurrent LLM + Embedding serving architecture: dual vLLM instances (LLM on port 8000, embedding on port 8001)
- References ADR-0053 (Replace Ollama with vLLM for Concurrent LLM + Embedding Serving)

## Version Bump
- Design doc: 1.18.0 → 1.19.0
- VERSION.md: Updated with v1.19.0 entry
- CHANGES.md: Added v1.19.0 changelog entry

## ADR Number Conflict
ADR-0020 is already taken by "Hierarchical Memory (Hot/Warm/Cold)" (Superseded). Used ADR-0053 as next available number. The actual ADR file (`ADR-0053-replace-ollama-with-vllm.md`) needs to be created separately.

## Files Modified
- `docs/design/README.md` — Section 8.1 rewrite, version bump, changelog entry
- `VERSION.md` — v1.19.0 entry added
- `CHANGES.md` — v1.19.0 changelog entry added
