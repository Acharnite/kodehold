# ADR-0006: Second Opinion Protocol

## Status

Accepted

## Context

No single LLM is perfect. Different models have different strengths in reasoning, code generation, security analysis, and creative design. For critical decisions — architecture choices, security-sensitive code, complex bugs — relying on a single model's output increases risk. A second opinion from a different model provides a cross-check.

Key forces:
- Second opinions cost additional tokens — they must be reserved for high-impact decisions
- The secondary model should be meaningfully different (different architecture, different training data)
- The process must not block the primary workflow — second opinions run in parallel or asynchronously where possible

## Decision

### Trigger Conditions

The Director automatically triggers a second opinion when any of these conditions are met:

1. **Architecture Decision**: Any new ADR or significant design change
2. **Security-Critical Code**: Authentication, authorization, encryption, input sanitization
3. **Complex Bug**: A bug that has escaped initial review and testing
4. **Ambiguous Design**: Design review results in a split decision (Reviewers disagree)
5. **Manual Request**: Any team member can request a second opinion via the Director

### Protocol

```
1. Director identifies trigger condition
2. Context is packaged:
   - Relevant design doc excerpt (max 2k tokens)
   - Code snippet or diff (max 4k tokens)
   - Specific question (max 500 tokens)
   - Primary model's proposed solution (max 2k tokens)
3. Request sent to secondary LLM (different model/provider)
4. Secondary response received
5. Comparison:
   - Agreement → proceed with confidence
   - Minor disagreement → Reviewers evaluate and reconcile
   - Major disagreement → Director escalates to Architects for design review
6. Result recorded in ICM by Scribes
```

### Secondary Model Selection

The secondary model must be meaningfully different from the primary:
- If primary is qwen2.5-coder, secondary could be llama3.1, deepseek-coder, or mixtral
- If primary is local Ollama, secondary could be an OpenAI-compatible remote API
- Light mode: skip second opinion for non-critical triggers to save tokens

### Cost Management

- Second opinion is limited to 3 concurrent requests per project phase
- Token cost is logged per second opinion in ICM
- If token budget is constrained, only security-critical triggers activate

## Consequences

- Positive: Cross-model validation catches errors single-model workflows miss
- Positive: Structured protocol prevents second opinions from blocking the main workflow
- Positive: ICM logging creates a trace of which decisions were cross-checked
- Negative: Additional token cost per second opinion request
- Negative: Adds latency to critical decisions (mitigated by parallel execution)
- Negative: Requires a second available LLM provider (extraneous configuration)
