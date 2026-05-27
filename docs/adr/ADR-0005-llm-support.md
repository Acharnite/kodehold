# ADR-0005: LLM Support and Light Mode

## Status

Accepted

## Context

KodeHold must support multiple LLM providers to avoid vendor lock-in and to enable second opinions (see ADR-0006). Ollama is available as a local provider for private inference. Users bring their own model via OpenCode's global configuration — KodeHold does not mandate a specific model.

Key forces:
- The user's default OpenCode model is the primary LLM (e.g. deepseek-v4-flash, gpt-4, etc.)
- Ollama should be available as an optional local provider for users who want private inference
- Light mode should give users an option to run on smaller local LLMs with >= 32k context
- OpenCode provides the LLM abstraction layer via `@ai-sdk/openai-compatible`

## Decision

### Provider Architecture

```
KodeHold → OpenCode → User's default model (primary)
                     → Ollama (optional local provider)
                     → OpenAI-compatible API (secondary)
```

All LLM communication goes through OpenCode's provider interface. No direct LLM calls. This ensures:
- Provider swapping without code changes — the user's global OpenCode config determines the default
- Consistent tool-use and message format
- Built-in retry, error handling, and streaming

### Model Configuration

KodeHold does not configure a default model in `opencode.json`. The user's global OpenCode model is used. Each team subagent has no model override in its frontmatter — all teams inherit the same default model from the user's OpenCode configuration.

Users who want Ollama can configure it in their OpenCode provider settings. The Ollama provider definition in `opencode.json` makes it available as an option without forcing its use.

### Light Mode (32k Context)

Light mode is an optional execution mode designed for users who want to run KodeHold on a local LLM with a context window of at least 32k tokens. It is NOT auto-detected — it must be explicitly activated.

When activated, light mode applies:

1. **Prompt Compression**: All prompts use the minimal template set. No explanatory text, no chain-of-thought examples.
2. **RTK Mandatory**: All file and git output goes through RTK compact mode — no exceptions.
3. **ICM Summaries**: Context is loaded from ICM summaries, not full memories. Full text is retrieved only on demand.
4. **Chunked Processing**: Files > 100 lines are processed in chunks. Each chunk is summarized before the next is loaded.
5. **Token Budget**: A hard 28k token budget per operation (leaving 4k for response). Operations exceeding the budget are split.
6. **No Redundancy**: No repeated context. Each message contains only new or changed information.
7. **Collapsed Teams**: Reviewers and Testers roles may be collapsed into a single "Quality" team to reduce orchestration overhead.
8. **English Only**: All responses in English. Token savings of ~15% vs Danish (or other non-English languages).

### Activation

Light mode is activated by setting the environment variable `KODEHOLD_LIGHT=1`. It is NOT auto-detected — the user chooses when to enable it.

## Consequences

- Positive: Users bring their own model — no vendor lock-in, no KodeHold-imposed model choice
- Positive: Light mode gives users a path to run on local LLMs with >= 32k context
- Positive: Ollama provider is available for those who want it, invisible to those who don't
- Negative: Light mode reduces output quality — summaries lose detail
- Negative: Collapsed teams in light mode violate separation of concerns principle
- Neutral: Provider abstraction via OpenCode means adding a new provider is config-only
