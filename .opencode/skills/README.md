# KodeHold Skills

This directory contains reusable KodeHold skills — packaged workflows that can be invoked by the Director or any team.

## Structure

Each skill lives in its own subdirectory with a `SKILL.md` entry point:

```
skills/
├── README.md               # This file — skill index
├── icm-knowledge-flow/
│   └── SKILL.md            # 7-step ICM knowledge flow
└── state-awareness/
    └── SKILL.md            # Lifecycle state checking + mismatch protocol
```

## Available Skills

| Skill | Description |
|-------|-------------|
| [icm-knowledge-flow](icm-knowledge-flow/SKILL.md) | Shared 7-step ICM Knowledge Flow used by all 6 team subagents. Replaces ~50 lines of duplication per agent. |
| [state-awareness](state-awareness/SKILL.md) | Lifecycle state check preamble and mismatch reporting protocol. Used by all team subagents. |
