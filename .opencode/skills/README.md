# KodeHold Skills

This directory contains reusable KodeHold skills — packaged workflows that can be invoked by the Director or any team.

## Structure

Each skill lives in its own subdirectory with a `SKILL.md` entry point:

```
skills/
├── README.md               # This file — skill index
├── icm-knowledge-flow/
│   └── SKILL.md            # 7-step ICM knowledge flow
├── investigate/
│   └── SKILL.md            # Systematic debugging with root cause investigation
└── state-awareness/
    └── SKILL.md            # Lifecycle state checking + mismatch protocol
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [icm-knowledge-flow](icm-knowledge-flow/SKILL.md) | Shared 7-step ICM Knowledge Flow used by all 6 team subagents. Replaces ~50 lines of duplication per agent. |
| [investigate](investigate/SKILL.md) | Systematic debugging with root cause investigation. Iron Law: no fixes without root cause. 4 phases: investigate → analyze → hypothesize → implement. Adapted from gstack. |
| [state-awareness](state-awareness/SKILL.md) | Lifecycle state check preamble and mismatch reporting protocol. Used by all team subagents. |
