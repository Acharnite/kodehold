---
name: icm-knowledge-flow
description: |
  Shared ICM Knowledge Flow used by all 6 team subagents.
  8-step protocol: search learnings → execute task → store learnings → refine concepts.
  Triggers on delegation. Use at session start and after each delegation round.
---

# ICM Knowledge Flow

Before every task, follow this knowledge flow to build on past experience and preserve new insights from the work:

## Steps

1. **Search shared learnings** — search `kodehold-learnings` memoir for relevant patterns
2. **Search team learnings** — search `<team>-learnings` memoir for team-specific patterns
3. **Execute task** — perform the team's standard workflow
4. **Reflect** — after execution, identify what was learned: new patterns, issues found, insights gained
5. **Pre-store consolidation check** — if the target topic has >5 entries, consolidate first (ICM warns at >7)
6. **Store shared learnings** — save findings from this task that benefit all teams in `kodehold-learnings`
7. **Store team learnings** — save team-specific findings from this task in `<team>-learnings`
8. **Distill/refine concepts** — add/refine concepts in relevant memoirs based on what was learned

## Usage

Each team agent references this skill in its ICM Knowledge Flow section, parameterized with team-specific search queries and memoir names.

**Important:** Steps 5-8 run AFTER the task (step 3). First do the work, then store what you learned from it.
