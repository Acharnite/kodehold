# KodeHold Skills

This directory contains reusable KodeHold skills — packaged workflows that can be invoked by the Director or any team.

## Structure

Each skill lives in its own subdirectory with a `SKILL.md` entry point:

```
skills/
├── README.md               # This file — skill index
├── opencode-rag-knowledge-flow/
│   └── SKILL.md            # Pre-task RAG knowledge retrieval (search_semantic, find_usages)
├── agentmemory-knowledge-flow/
│   └── SKILL.md            # [DEPRECATED] Pre-task agentmemory knowledge retrieval
├── investigate/
│   └── SKILL.md            # Systematic debugging with root cause investigation
├── kodehold-routines/
│   └── SKILL.md            # Standard workflow routine definitions
├── resume/
│   └── SKILL.md            # Resume interrupted sessions from .opencode/memory/checkpoints
├── ponytail-review/
│   └── SKILL.md            # Over-engineering analysis for code review
├── ponytail-audit/
│   └── SKILL.md            # Whole-repo over-engineering scan
└── state-awareness/
    └── SKILL.md            # Lifecycle state checking + mismatch protocol
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [opencode-rag-knowledge-flow](opencode-rag-knowledge-flow/SKILL.md) | Pre-task knowledge retrieval via `search_semantic`, `find_usages`, `get_file_skeleton`, `describe_image`. (Replaces the deprecated `agentmemory-knowledge-flow` per ADR-0050.) |
| [agentmemory-knowledge-flow](agentmemory-knowledge-flow/SKILL.md) | ⚠️ DEPRECATED — replaced by opencode-rag-knowledge-flow (see ADR-0050). |
| [investigate](investigate/SKILL.md) | Systematic debugging with root cause investigation. Iron Law: no fixes without root cause. 4 phases: investigate → analyze → hypothesize → implement. Adapted from gstack. |
| [resume](resume/SKILL.md) | Resume interrupted sessions from .opencode/memory/checkpoints. Uses file reads and search_semantic for checkpoint recovery. |
| [ponytail-review](ponytail-review/SKILL.md) | Over-engineering analysis for code review. Companion to The Ladder (ADR-0049). Tags diffs with delete:/stdlib:/native:/yagni:/shrink: tags. Loaded by Reviewers during Ladder compliance checks. |
| [ponytail-audit](ponytail-audit/SKILL.md) | Whole-repo over-engineering audit. Scans entire codebase for complexity using 9 hunts. Produces ranked report with net line + dependency reduction. |
| [kodehold-routines](kodehold-routines/SKILL.md) | Standard workflow routine step tables for ADR creation, implementation, bugfix, shipping gate, and GitHub PR flows. Load when the Director needs to instantiate a routine. |
| [state-awareness](state-awareness/SKILL.md) | Lifecycle state check preamble and mismatch reporting protocol. Used by all team subagents. |
