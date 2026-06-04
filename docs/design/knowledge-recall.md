# Project: Knowledge Recall Protocol
**Version:** 1.0
**Status:** Active
**Design Authority:** Architects
**Last Reviewed:** 2026-06-03

---

## 1. Purpose & Scope

### Purpose

Fix the knowledge recall path in agentmemory's lesson system so that teams searching for relevant patterns and learnings before starting work consistently get meaningful results.

### Scope

This design document covers the **recall-only** improvements to the Agentmemory Knowledge Flow:

1. **SKILL.md update** — project scoping, increased limits, team-prefixed queries, fallback step
2. **Agent file updates** — 5 agent files with corrected pre-task knowledge flow sections
3. **Batch tagging** — companion lessons for all 122 existing lessons with team tags + `kodehold-learnings` topic tag

### Out of Scope

- Changes to the lesson **save** protocol — auto-consolidation handles storage
- Changes to scribes.md or director.md — no protocol changes needed
- New MCP tools or schema migrations — companion lesson approach avoids infrastructure changes
- The crystals/signals pipeline (ADR-0033) — lessons produced by crystals are already stored correctly; they just weren't discoverable

---

## 2. Requirements

### Functional Requirements

| ID | Requirement | Priority | Verification |
|----|-------------|----------|--------------|
| FR-1 | Teams searching for lessons before work must get relevant results | P0 | Per-team recall verification |
| FR-2 | All `memory_lesson_recall` calls must use `project="kodehold"` | P0 | Code inspection |
| FR-3 | Default recall limit must be at least 10 for primary searches | P1 | Code inspection |
| FR-4 | Query format must include team prefix (e.g., `"engineers lessons patterns ..."`) | P1 | Code inspection |
| FR-5 | Fallback search must exist for queries returning <3 results | P1 | Code inspection |
| FR-6 | All 122 existing lessons must have companion lessons with team tags | P1 | Count verification |
| FR-7 | No changes to the lesson save path or infrastructure | P0 | No infra changes |

### Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1 | Recall query latency | <500ms (agentmemory hybrid search) |
| NFR-2 | Storage impact | <50KB (122 companion lessons) |
| NFR-3 | Backwards compatibility | Zero breakage — existing queries still work |
| NFR-4 | Idempotency | Batch script can be re-run safely |

---

## 3. Architecture Overview

### Before (Broken Recall)

```
Team starts work
       │
       ▼
agentmemory_memory_lesson_recall(query="lessons patterns", limit=5)
       │
       ▼
    [0 results]  ← No project scope, no team tags, limit too low
       │
       ▼
Team works without context — lessons ignored
```

### After (Fixed Recall)

```
Team starts work
       │
       ▼  Step 1: Search shared learnings
agentmemory_memory_lesson_recall(
    query="<team> lessons patterns <keywords>",
    limit=10,
    project="kodehold"
)
       │
       ▼  If < 3 results
agentmemory_memory_lesson_recall(
    query="<team> <keywords>",
    limit=10,
    project="kodehold"
)
       │
       ▼  If still < 3 results
agentmemory_memory_lesson_recall(
    query="<team> lessons",
    limit=5,
    project="kodehold"
)
       │
       ▼
Team works with context → relevant patterns discovered
```

### Data Flow

```
┌─────────────────────────────────────────────────────┐
│                 Storage Path (unchanged)              │
│                                                       │
│  Crystal → memory_lesson_save → agentmemory DB       │
│  (ADR-0033)    (auto-consolidation)                   │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                 Recall Path (fixed)                   │
│                                                       │
│  Team pre-task → memory_lesson_recall(               │
│     query="<team> lessons patterns ...",              │
│     limit=10,                                         │
│     project="kodehold"                                │
│  ) → relevant lessons found                           │
│                                                       │
│  Companion lessons provide team-tagged                │
│  discoverability for legacy untagged lessons          │
└─────────────────────────────────────────────────────┘
```

---

## 4. Component Design

### 4.1 SKILL.md — Agentmemory Knowledge Flow (`.opencode/skills/agentmemory-knowledge-flow/SKILL.md`)

The skill file defines a 2-step pre-task recall protocol with a fallback:

**Step 1 — Search shared learnings:**
```python
agentmemory_memory_lesson_recall(
    query="<team-name> lessons patterns <relevant-keywords>",
    limit=10,
    project="kodehold"
)
```

**Step 2 — Search team learnings (broader fallback):**
```python
agentmemory_memory_lesson_recall(
    query="<team-name> <relevant-keywords>",
    limit=10,
    project="kodehold"
)
```

**Step 3 — Fallback (if Steps 1-2 return <3 results):**
```python
agentmemory_memory_lesson_recall(
    query="<team-name> lessons",
    limit=5,
    project="kodehold"
)
```

**Mode Selection Table** — defines per-team query prefixes:

| Team | Recall Query Prefix |
|------|---------------------|
| Engineers | `engineers` |
| Testers | `testers` |
| Reviewers | `reviewers` |
| FLS | `fls` |
| Architects | `architects` |
| Scribes | N/A (no knowledge flow needed) |

### 4.2 Agent File Updates

Each affected agent file (engineers.md, reviewers.md, testers.md, architects.md, fls.md) has its "Agentmemory Knowledge Flow" section updated to:

1. Remove broken `kodehold-teams` ICM references
2. Reference the skill correctly with team-specific parameters
3. Use the standard pre-task protocol format

The section format (example from engineers.md):
```markdown
## Agentmemory Knowledge Flow (Pre-task Mode)

Follow the Agentmemory Knowledge Flow skill protocol in **Pre-task mode**:
1. Search for relevant engineering patterns via `agentmemory_memory_lesson_recall` before starting work
2. Search for team-specific engineering patterns via `agentmemory_memory_lesson_recall` before starting work
```

### 4.3 Companion Lesson Script (`scripts/tag-lessons.py`)

A one-time batch script that:
1. Recalls all existing lessons from agentmemory
2. Categorizes each lesson by primary team tag based on content keywords
3. Creates companion lessons with:
   - Unique content marker (UUID suffix) to avoid auto-strengthening collision
   - Team tags (e.g., `engineers`, `testers`)
   - `kodehold-learnings` topic tag
   - Project field set to `"kodehold"` slug format
   - Confidence: 0.8

**Tag assignment rules:**

| Content Keywords | Primary Team Tag |
|-----------------|-----------------|
| code, implement, refactor, fix, feature | engineers |
| test, verify, assert, coverage, regression | testers |
| review, reviewer, code review, design review | reviewers |
| design, architect, ADR, decision, technology | architects |
| debug, investigate, triage, hotfix, error, bug | fls |
| document, memory, changelog, scribe | scribes |

Lessons matching multiple teams get multiple team tags.

---

## 5. Data Model

### Companion Lesson Structure

```
Field        : Value
─────────────┼───────────────────────────────────────────────
content      : "[kodehold-learnings companion] <summary> [<uuid>]"
tags         : "<team>, kodehold-learnings, <domain-keywords>"
confidence   : 0.8
project      : "kodehold"
```

### Rationale for Design Choices

| Choice | Rationale |
|--------|-----------|
| Unique content marker (`[<uuid>]`) | Prevents `memory_lesson_save` from auto-strengthening against the original lesson |
| `[kodehold-learnings companion]` prefix | Makes companion lessons identifiable and filterable |
| Confidence 0.8 | High enough to rank well in recall, low enough to not overshadow originals |
| `project="kodehold"` | Matches ADR-0036 slug convention for project-scoped recall |

### Tag Taxonomy

| Tag | Type | Purpose |
|-----|------|---------|
| `kodehold-learnings` | Topic | All lessons — enables global "show me everything" queries |
| `engineers` | Team | Engineering-specific patterns |
| `testers` | Team | Testing-specific patterns |
| `reviewers` | Team | Review-specific patterns |
| `architects` | Team | Architecture-specific patterns |
| `fls` | Team | Support-specific patterns |
| `scribes` | Team | Documentation-specific patterns |

---

## 6. API Design

### 6.1 Recall API (Usage Pattern)

The recall API is agentmemory's existing `memory_lesson_recall` — no new API is introduced.

**Standard recall for team <T>:**
```python
agentmemory_memory_lesson_recall(
    query="<T> lessons patterns <keywords>",
    limit=10,
    project="kodehold"
)
```

**Broader fallback:**
```python
agentmemory_memory_lesson_recall(
    query="<T> <keywords>",
    limit=10,
    project="kodehold"
)
```

**Generic fallback (when specific keywords fail):**
```python
agentmemory_memory_lesson_recall(
    query="<T> lessons",
    limit=5,
    project="kodehold"
)
```

### 6.2 Batch Tag Script

`scripts/tag-lessons.py` — command-line tool:

```
Usage: python3 scripts/tag-lessons.py [--dry-run]

Options:
  --dry-run    Report what would be tagged without creating companions

Output:
  Created N companion lessons
  Teams: engineers=42, testers=18, reviewers=15, architects=25, fls=12, scribes=10
```

---

## 7. Implementation Plan

### Phase 1: SKILL.md Update

**Actions:**
1. Add `project="kodehold"` to all `memory_lesson_recall` calls
2. Change `limit=5` → `limit=10` for primary and secondary searches
3. Change query format to team-prefixed: `"<team-name> lessons patterns <keywords>"`
4. Add fallback step: if <3 results, broader search with `limit=5`
5. Update Mode Selection table with per-team query prefixes

**Files modified:** `.opencode/skills/agentmemory-knowledge-flow/SKILL.md`

### Phase 2: Agent File Updates

**Actions:**
1. For each agent file (engineers.md, reviewers.md, testers.md, architects.md, fls.md):
   - Remove broken `kodehold-teams` references
   - Update pre-task knowledge flow section to reference the skill correctly
   - Standardize section format across all files

**Files modified:**
- `.opencode/agents/engineers.md`
- `.opencode/agents/reviewers.md`
- `.opencode/agents/testers.md`
- `.opencode/agents/architects.md`
- `.opencode/agents/fls.md`

### Phase 3: Batch Tagging Script

**Actions:**
1. Create `scripts/tag-lessons.py` — batch companion lesson creation
2. Run script: `python3 scripts/tag-lessons.py`
3. Verify: count companion lessons created, spot-check team tags
4. Run with `--dry-run` first to verify tagging decisions

**Files created:** `scripts/tag-lessons.py`

### Phase 4: Verification

**Actions:**
1. Per-team recall verification — simulate each team's pre-task query
2. Verify each team gets ≥3 relevant results from their recall query
3. Verify companion lessons appear in generic `kodehold-learnings` queries
4. Verify no regression for existing queries (backwards compatibility)

---

## 8. Testing Strategy

### 8.1 Per-Team Recall Verification

For each team, run the standard recall query and verify ≥3 relevant results:

| Team | Query | Expected Min Results |
|------|-------|---------------------|
| Engineers | `agentmemory_memory_lesson_recall(query="engineers lessons patterns code", limit=10, project="kodehold")` | ≥3 |
| Testers | `agentmemory_memory_lesson_recall(query="testers lessons patterns test", limit=10, project="kodehold")` | ≥3 |
| Reviewers | `agentmemory_memory_lesson_recall(query="reviewers lessons patterns review", limit=10, project="kodehold")` | ≥3 |
| Architects | `agentmemory_memory_lesson_recall(query="architects lessons patterns design", limit=10, project="kodehold")` | ≥3 |
| FLS | `agentmemory_memory_lesson_recall(query="fls lessons patterns debug", limit=10, project="kodehold")` | ≥3 |

### 8.2 Fallback Verification

For each team, verify the fallback path works when primary results <3:

| Query | Expected Behavior |
|-------|------------------|
| `agentmemory_memory_lesson_recall(query="<team> lessons", limit=5, project="kodehold")` | Returns ≥1 result |

### 8.3 Tag Coverage Verification

| Check | Method |
|-------|--------|
| All 122 originals have companions | Count lessons with `content LIKE "[kodehold-learnings companion]%"` |
| Each team tag has ≥5 lessons | Search by tag + project filter |
| No duplicate companion content markers | Verify UUID uniqueness |

### 8.4 Regression Testing

| Check | Method |
|-------|--------|
| Existing queries still work | Run a pre-existing generic query, verify returns results (may be different results, but no errors) |
| Original lessons untouched | Compare original lessons before/after — no content changes |
| Scribes/director not affected | Verify scribes.md and director.md have no knowledge flow changes |

---

## 9. ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-0030](../adr/ADR-0030-agentmemory-knowledge-flow.md) | Agentmemory Knowledge Flow | Accepted |
| [ADR-0038](../adr/ADR-0038-knowledge-recall.md) | Knowledge Recall Protocol | **Accepted** |
| [ADR-0029](../adr/ADR-0029-agentmemory-migration-strategy.md) | ICM → Agentmemory Migration Strategy | Accepted |
| [ADR-0036](../adr/ADR-0036-project-slug-convention.md) | Project Slug Convention | Accepted |
| [ADR-0033](../adr/ADR-0033-crystals-signals.md) | Crystals + Signals for KodeHold | Accepted |

---

## 10. Open Questions

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| 1 | Should `memory_lesson_save` support tag updates in the future? | Deferred | Not needed for recall fix. If agentmemory adds this, originals can be updated and companions retired. |
| 2 | What happens when lessons are consolidated by agentmemory's 4-tier pipeline? | Resolved | Companion lessons are lightweight text records — consolidation treats them as normal lessons. No special handling needed. |
| 3 | Should the batch script be run periodically for new untagged lessons? | Resolved | Not needed — new lessons created via crystals (ADR-0033) are stored with team tags from the start. Only legacy lessons needed companions. |

---

## 11. Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0 | 2026-06-03 | Initial design document — Knowledge Recall Protocol (recall-only scope) |
