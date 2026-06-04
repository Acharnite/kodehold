# ADR-0040: Headroom Integration — Context Compression Layer

## Status

Proposed

**Version:** 1.0
**Last Updated:** 2026-06-04

## Context

### Current Token Strategy

KodeHold's existing token optimization strategy (ADR-0007) establishes per-phase token budgets, tiered context loading, and English-only conventions. Session compression (ADR-0019) provides manual compression every 4 delegation rounds via Scribes-generated summaries. Pre-flight enforcement (ADR-0039) ensures knowledge recall runs before each delegation.

Despite these measures, KodeHold has three gaps:

1. **No real-time compression.** Tool output, chat history, and intermediate results accumulate without automatic compression. The 4-round manual cycle saves 60-80% but happens in batches — the space between rounds is unmanaged. Models at 32K context windows (Ollama) still approach overflow in high-volume sessions.

2. **No tool-output compression.** Large JSON blobs, file reads, and command output consume significant context. ADR-0007's tiered loading handles design docs, but arbitrary tool output is uncompressed.

3. **No automated failure mining.** When sessions fail or produce poor results, Scribes manually distills lessons (ADR-0033 crystals feed into this). There is no automated pipeline that ingests failed sessions and extracts actionable patterns into agent instructions.

### What Headroom Is

Headroom (https://github.com/chopratejas/headroom) by chopratejas is an Apache 2.0 licensed toolkit for agent context compression. It provides:

- **6 compression algorithms:** SmartCrusher (JSON), CodeCompressor (AST), Kompress-base (HF model), CacheAligner, ContentRouter, IntelligentContext
- **Real-time compression:** 60-95% token reduction on agent workloads
- **Reversible compression (CCR):** Originals stored locally for decompression on demand
- **`headroom learn`:** Mines failed agent sessions, extracts root causes, and writes findings to AGENTS.md
- **MCP server:** Exposes `headroom_compress`, `headroom_retrieve`, `headroom_stats` as MCP tools
- **Multiple modes:** Library (inline), Proxy (sidecar), Agent wrap (wrapper), MCP server

### Key Forces

1. **Token cost is both monetary and contextual.** API models cost per token; small context models (32K) hit limits in active sessions. Real-time compression directly addresses both.

2. **Manual compression is insufficient.** Scribes' 4-round cycle is reactive and coarse-grained. Real-time compression would save context continuously, extending session length without manual intervention.

3. **Failure mining is ad-hoc.** Crystals capture completed work, but failed sessions and near-misses are lost unless a human or Scribes explicitly distills them. `headroom learn` automates this.

4. **External dependency risk.** Headroom is a third-party tool with its own release cadence, bugs, and compatibility constraints. Integration must be incremental and reversible.

5. **Complementary to agentmemory, not competing.** Agentmemory provides persistent long-term memory (working → episodic → semantic → procedural). Headroom provides ephemeral real-time compression. They serve different layers of the stack.

## Decision

Adopt Headroom in a phased approach starting with `headroom learn` (Architect's Option C — Hybrid), with controlled evaluation before deeper integration.

### Why Phased?

Each phase validates the next. If `headroom learn` provides value with minimal friction, we proceed to MCP tool registration. If MCP tools demonstrate reliable compression on workspace projects, we evaluate proxy integration. Any phase can be halted independently.

### Why Start with `headroom learn`?

`headroom learn` is the lowest-risk entry point:

- No changes to the delegation flow or tool stack
- Runs post-hoc on failed sessions — no runtime risk
- Outputs directly to AGENTS.md, which KodeHold already uses for agent instructions
- Provides immediate value (automated failure mining) with almost zero integration cost

## Implementation Phases

### Phase 1: `headroom learn` Integration (Immediate)

**Timeline:** Immediate
**Risk:** Very low
**Effort:** One-time setup + documentation changes

1. Install Headroom: `pip install headroom-ai`
2. Add `headroom learn` to Scribes' failure distillation workflow:
   - After a failed session (or on explicit request), Scribes runs `headroom learn --session <path> --output AGENTS.md`
   - Review output, integrate actionable findings into agent instructions
3. Document the protocol in Scribes' workflow

**Success criteria:** Scribes can run `headroom learn` on a failed session and produce actionable AGENTS.md entries. No regression in existing workflows.

### Phase 2: MCP Tools Registration (After Phase 1)

**Timeline:** After Phase 1 validated
**Risk:** Low
**Effort:** Register MCP tools, update Director/Scribes protocols

1. Register Headroom MCP server in `.opencode/mcp.json`:
   ```json
   {
     "headroom": {
       "command": "headroom",
       "args": ["mcp"],
       "type": "stdio"
     }
   }
   ```
2. Expose optional compression at key choke points:
   - After large tool outputs (before they enter chat history)
   - Before session checkpoint storage
   - On explicit Director request (compression opt-in)
3. Update Director's protocol to allow opt-in compression calls

**Success criteria:** MCP tools (`headroom_compress`, `headroom_retrieve`, `headroom_stats`) are accessible. Compression can be triggered on demand.

### Phase 3: Controlled Evaluation on Workspace Project (1 Week)

**Timeline:** After Phase 2
**Risk:** Low
**Effort:** Test on a workspace project, measure savings

1. Select a workspace project (e.g., a medium-complexity adopted project)
2. Run a full delegation cycle with Headroom compression enabled at choke points
3. Measure:
   - Token reduction per compression event
   - Impact on output quality (correctness, completeness)
   - Latency overhead
   - Reliability (error rate, decompression success)
4. Compare against baseline (same project without Headroom)

**Success criteria:** Quantitative data on compression ratio, quality impact, and reliability. Decision on Phase 4 based on data.

### Phase 4: Full Proxy Integration (If Evaluation Passes)

**Timeline:** After Phase 3, conditional on positive evaluation
**Risk:** Medium
**Effort:** Infrastructure setup, proxy configuration, monitoring

1. Run `headroom proxy --port 8787` as a sidecar process
2. Configure KodeHold's LLM endpoint to route through the proxy
3. Enable real-time transparent compression of all LLM-bound context
4. Monitor for quality degradation, latency, and reliability issues

**Success criteria:** Proxy operates transparently with measurable token savings and no quality regression. Rollback plan: disable proxy and route directly.

## Consequences

### Positive

1. **Automated failure mining.** `headroom learn` extracts actionable patterns from failed sessions without manual effort, closing a gap in KodeHold's knowledge loop.

2. **Real-time compression.** Phases 2-4 progressively add real-time compression, reducing context pressure between Scribes' manual compression cycles.

3. **KV cache optimization.** CacheAligner (one of Headroom's algorithms) optimizes KV cache usage, potentially improving inference speed on cached contexts.

4. **Reversible compression.** CCR ensures no information is permanently lost — originals can be retrieved if needed.

5. **Complementary to existing infrastructure.** Agentmemory handles persistent knowledge; Headroom handles ephemeral compression. They address different layers without overlap.

6. **Incremental adoption.** Each phase can be halted independently. If Headroom proves unreliable, only the completed phases are affected.

### Negative

1. **External dependency.** Headroom adds a third-party dependency with its own maintenance burden, release cadence, and potential breaking changes.

2. **New infrastructure.** Even at Phase 2 (MCP), Headroom requires installation, configuration, and monitoring. Phase 4 adds a proxy process.

3. **Quality risk.** Compression is inherently lossy. Aggressive settings may discard nuance needed for complex tasks.

4. **Latency overhead.** Compression algorithms add processing time. Real-time compression (Phase 4) could increase perceived latency.

### Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | **Headroom project abandonment or breaking changes** | Low | High | Pin a specific version. Maintain rollback capability. Open source — can fork if needed. |
| 2 | **Compression degrades output quality** | Medium | Medium | Phase 3 evaluation measures quality impact. Conservative compression settings. Reversible (CCR). |
| 3 | **Proxy adds reliability failure point** | Low | Medium | Phase 4 proxy includes health checks and automatic bypass on failure. |
| 4 | **`headroom learn` produces low-quality output** | Medium | Low | Output is reviewed by Scribes before integration. No automated ingestion of learn output. |
| 5 | **Incompatibility with specific LLM providers** | Low | Medium | Proxy mode is configurable. Can fall back to MCP-only or library mode per provider. |

## Alternatives Considered

### Option A: Full Proxy Integration (Rejected for Now)

Run `headroom proxy --port 8787` as a sidecar between KodeHold and the LLM, enabling transparent real-time compression.

**Positive:**
- Maximum token savings (60-95% on agent workloads)
- Transparent to all agents — no protocol changes
- Works with any LLM provider

**Negative:**
- Highest infrastructure complexity
- Proxy is a new failure point in the critical path
- Quality impact is harder to measure and control
- If proxy fails, KodeHold is blocked
- Cannot evaluate incrementally

**Why rejected for now:** Too much risk without validation. Proxy integration should only proceed after Phases 1-3 demonstrate value and reliability.

### Option B: `headroom learn` Only (Rejected)

Adopt only `headroom learn` for automated failure mining, without MCP tools or proxy compression.

**Positive:**
- Lowest risk and effort
- Addresses the failure-mining gap
- No runtime changes

**Negative:**
- Does not address the real-time compression gap
- Misses 60-95% potential token savings from compression algorithms
- Phase 2 and 3 provide evaluation data that informs future decisions

**Why rejected:** Addresses only one of three gaps. The real-time compression gap (tool output, chat history) is equally important. Phases 2-3 are low-risk and provide essential data.

### Option C: Hybrid — `headroom learn` + MCP Tools (Selected)

Start with `headroom learn` (immediate value), then register MCP tools for opt-in compression (controlled evaluation), with proxy as a potential future step.

**Positive:**
- Lowest-risk path to maximum value
- Each phase is independently valuable and reversible
- Evaluation data from Phase 3 informs the proxy decision
- No single point of failure (MCP tools are opt-in)
- Addresses all three gaps (failure mining, real-time compression, tool-output compression)

**Negative:**
- Slower time-to-value for proxy-level compression
- Requires multi-phase planning and execution
- MCP tool registration requires OpenCode configuration changes

**Why selected:** Provides the best risk/reward profile. Immediate value from `headroom learn`, controlled evaluation before deeper integration, and a clear path to proxy if warranted.

### Do Nothing (Rejected)

Continue with the current strategy: manual session compression every 4 rounds, no automated failure mining, no real-time compression.

**Why rejected:** The gaps are real and growing. As KodeHold scales to more projects and larger workloads, manual compression and ad-hoc failure mining become bottlenecks. Headroom addresses these gaps with a proven, available tool.

## Integration with Agentmemory

Headroom and agentmemory serve complementary functions in KodeHold's memory architecture:

| Aspect | Agentmemory | Headroom |
|--------|-------------|----------|
| **Purpose** | Persistent long-term memory | Ephemeral real-time compression |
| **Data** | Knowledge, lessons, decisions | Tool output, chat history, intermediate results |
| **Persistence** | Permanent (tiered consolidation) | Temporary (reversible via CCR) |
| **Granularity** | Structured memories + lessons | Raw text + structured data |
| **Access** | Recall, query, graph traversal | Compress, retrieve, stats |
| **Lifecycle** | Working → Episodic → Semantic → Procedural | In-session only (decompressed on demand) |

**Data flow:** Headroom compresses tool output before it enters the model's context window. Key decisions and patterns from compressed output are still stored in agentmemory via the normal knowledge flow (crystals → lessons → memory). They do not compete — they operate at different stages of the data pipeline.

**CCR integration:** When Headroom compresses content that feeds into a crystal (ADR-0033), the original uncompressed content is available via `headroom_retrieve` if Scribes needs it for detailed analysis.

## ADR References

- **ADR-0007** (Token Optimization Strategy) — establishes per-phase token budgets, tiered loading, English-only convention
- **ADR-0019** (Session Context Compression via Periodic ICM Summaries) — manual compression every 4 delegation rounds (Superseded — replaced by agentmemory)
- **ADR-0039** (Pre-Flight Knowledge Check Enforcement) — ensures knowledge recall before delegation
- **ADR-0030** (Agentmemory Knowledge Flow) — defines the knowledge flow protocol
- **ADR-0033** (Crystals + Signals) — crystals produce lessons via consolidation pipeline

## Open Questions

1. **Should we pin a specific version of Headroom?** Yes — pin to the latest stable release at time of Phase 1 installation. Version pinning prevents unexpected breaking changes. Revisit pin periodically.

2. **What is the evaluation criteria for Phase 3?**
   - Minimum 40% token reduction on compressed outputs without measurable quality degradation
   - Zero critical failures (compression or decompression errors that block work)
   - Latency overhead < 500ms per compression event
   - Scribes reports no workflow disruption
   - Comparison baseline: same project cycle without Headroom

3. **Which compression algorithms should be enabled by default?** Start with SmartCrusher (JSON) and CodeCompressor (AST) for structured data. Evaluate Kompress-base (HF model) for general text compression in Phase 3.

4. **Should `headroom learn` run automatically or on-demand?** Start on-demand (Scribes triggers it after failed sessions). If proven valuable, add a sentinel trigger for automatic execution.

5. **What is the rollback plan for Phase 4 proxy?** Disable proxy via configuration flag and route directly to LLM. No code changes required if proxy is a configurable endpoint.

## Changelog

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-06-04 | Initial ADR — Headroom integration evaluation |
