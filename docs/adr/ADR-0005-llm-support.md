# ADR-0005: LLM Support and Light Mode

## Status

Accepted

## Context

KodeHold must support multiple LLM providers to avoid vendor lock-in and to enable second opinions (see ADR-0006). Ollama is the primary provider for local, private inference. Additionally, many useful models have 32k context windows — the orchestrator must operate effectively within this constraint.

Key forces:
- Ollama runs locally, ensuring data privacy and zero API costs
- Different teams may benefit from different models (e.g., smaller models for review, larger for design)
- 32k context is the realistic baseline for many open-source models
- OpenCode provides the LLM abstraction layer via `@ai-sdk/openai-compatible`

## Decision

### Provider Architecture

```
KodeHold → OpenCode → @ai-sdk/openai-compatible → Ollama (default)
                                                  → OpenAI-compatible API (secondary)
```

All LLM communication goes through OpenCode's provider interface. No direct LLM calls. This ensures:
- Provider swapping without code changes
- Consistent tool-use and message format
- Built-in retry, error handling, and streaming

### Model Configuration

Each team can be configured with a different model in `opencode.json`:

```json
{
  "agent": {
    "defaultModel": "qwen2.5-coder:14b",
    "teams": {
      "architects":   "qwen2.5-coder:32b",
      "engineers":    "qwen2.5-coder:14b",
      "reviewers":    "qwen2.5-coder:14b",
      "testers":      "qwen2.5-coder:7b",
      "scribes":      "qwen2.5-coder:7b",
      "director":     "qwen2.5-coder:14b"
    }
  }
}
```

### Light Mode (32k Context)

Light mode is activated when the available model has ≤ 32k context. It applies the following constraints:

1. **Prompt Compression**: All prompts use the minimal template set. No explanatory text, no chain-of-thought examples.
2. **RTK Mandatory**: All file and git output goes through RTK compact mode — no exceptions.
3. **ICM Summaries**: Context is loaded from ICM summaries, not full memories. Full text is retrieved only on demand.
4. **Chunked Processing**: Files > 100 lines are processed in chunks. Each chunk is summarized before the next is loaded.
5. **Token Budget**: A hard 28k token budget per operation (leaving 4k for response). Operations exceeding the budget are split.
6. **No Redundancy**: No repeated context. Each message contains only new or changed information.
7. **Collapsed Teams**: In light mode, Reviewers and Testers roles may be collapsed into a single "Quality" team to reduce orchestration overhead.

### Activation

Light mode is auto-detected from the model's reported max context window, or manually activated with `KODEHOLD_LIGHT=1`.

## Consequences

- Positive: Ollama provides free, private, local inference
- Positive: Light mode makes KodeHold usable on consumer hardware with 32k models
- Positive: Per-team model config allows resource optimization (smaller models for simpler tasks)
- Negative: Light mode reduces output quality — summaries lose detail
- Negative: Collapsed teams in light mode violate separation of concerns principle
- Neutral: Provider abstraction via OpenCode means adding a new provider is config-only
