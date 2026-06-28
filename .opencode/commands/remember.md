---
name: remember
description: |
  Explicitly save an insight, decision, or learning to `.opencode/memory/` for future sessions.
  Writes structured markdown files for future sessions.
---

# /remember — Save Knowledge to `.opencode/memory/`

## Usage

```
/remember [what to remember]
```

## Instructions

1. Analyze what needs to be remembered — extract the core insight, decision, or fact.
2. Determine the appropriate type: decision, pattern, bug, lesson, or fact.
3. Determine a brief slug for the filename (2-4 lowercase hyphenated words).
4. Write to the appropriate `.opencode/memory/` subdirectory:
   - decisions → `.opencode/memory/decisions/<slug>.md`
   - patterns → `.opencode/memory/patterns/<slug>.md`
   - bugs → `.opencode/memory/bugs/<slug>.md`
   - lessons → `.opencode/memory/lessons/<slug>.md`
   - facts → `.opencode/memory/facts/<slug>.md`
5. Confirm the save and show the file path so the user knows where it was stored.

### File format

```
---
type: <type>
concepts: <comma-separated keyword phrases>
files: <comma-separated file paths if relevant>
date: <ISO 8601>
---

<full text content — preserve user's phrasing>
```
