# KodeHold Skills

This directory contains reusable KodeHold skills — packaged workflows that can be invoked by the Director or any team.

## Structure

Each skill lives in its own subdirectory with a `SKILL.md` entry point:

```
skills/
├── README.md               # This file — skill index
├── agentmemory-knowledge-flow/
│   └── SKILL.md            # Pre-task agentmemory knowledge retrieval
├── investigate/
│   └── SKILL.md            # Systematic debugging with root cause investigation
└── state-awareness/
    └── SKILL.md            # Lifecycle state checking + mismatch protocol
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [agentmemory-knowledge-flow](agentmemory-knowledge-flow/SKILL.md) | Pre-task knowledge retrieval for agents. Search agentmemory for relevant patterns and team-specific learnings before starting work. |
| [investigate](investigate/SKILL.md) | Systematic debugging with root cause investigation. Iron Law: no fixes without root cause. 4 phases: investigate → analyze → hypothesize → implement. Adapted from gstack. |
| [state-awareness](state-awareness/SKILL.md) | Lifecycle state check preamble and mismatch reporting protocol. Used by all team subagents. |
