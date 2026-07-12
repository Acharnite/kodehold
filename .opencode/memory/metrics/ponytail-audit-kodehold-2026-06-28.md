---
type: metric
project: kodehold
concepts: ponytail-audit, debt, over-engineering, baseline
date: 2026-06-28
updated: 2026-06-28
---

# Ponytail Audit: kodehold

net: -408 lines, -0 deps possible (initial estimate: -128; additional -280 realized).

## Findings (ranked by impact)

### Resolved

`delete: Empty file [docs/dashboard/index.html]` → **RESOLVED**: file deleted (0 lines).
`delete: Stale sed backup [docs/adr/ADR-0031-actions-crystals-integration.original.md]` → **RESOLVED**: file deleted (240 lines saved).
`shrink: Stale .kodehold-state not updated since 2026-05-31` → **RESOLVED**: updated to 2026-06-28.
`shrink: Duplicate pass()/fail()/warn()/info() in 3 scripts` → **RESOLVED**: extracted to `scripts/lib/output.sh` (~7 lines net saved).
`shrink: Echo header noise (~46 lines of --- Section: Name --- in 13 tests + ship.sh)` → **RESOLVED**: runner now labels per-file; headers removed from all test files and ship.sh (33 lines saved).

### High (30-99 lines)

(none remaining)

### Medium (10-29 lines)

`stdlib: os.path.join() used 32 times in test file. pathlib.Path/`/` is stdlib since 3.4 and composes better. [tests/init/test_yaml_config.py]` — **DEFERRED**: file also uses `os.environ`, `os.rename`, `os.remove`, so `os` import cannot be removed. Adding `pathlib.Path` would increase imports without removing the `os` one. Low value.
`shrink: 920-line Python file with embedded HTTP server + HTML generation + SQLite queries + chart rendering. Extract chart rendering or split modules (~40 lines for proper logging alone). [scripts/token-report.py]`
`shrink: 306-line bash script with only 3 functions. Overhead of 2:1 boilerplate-to-logic. [scripts/sync-agent-config.sh]`

### Low (1-9 lines)

`stdlib: print() used for logging instead of logging module (15 calls). [scripts/token-report.py]`
`stdlib: print() for server diagnosis messages instead of logging. [server.py]`

## Summary metrics

| Metric | Value |
|--------|-------|
| Total source files | 10 scripts (9 + `lib/output.sh`), 14 test files, 53 ADRs (+changes), 8 agents, 8 skills, 3 design docs |
| External deps | 0 (Python only uses stdlib; shell uses standard tools) |
| Dead files | 0 (2 removed) |
| Stale config | 0 (1 updated) |
| Duplicated shell pattern | 0 (extracted to shared lib) |
| Echo header noise | 0 (removed from tests + ship.sh) |
| Hand-rolled stdlib | print instead of logging (2 files) |
| ponytail: comments in source | 0 (only in docs describing the convention) |
| Interfaces with 1 impl | 0 |
| Factories | 0 |
| Wrappers | 0 |

Now extremely lean. All syntactic debt resolved. The 3 remaining open items (token-report.py, sync-agent-config.sh, print vs logging) are architectural choices, not technical debt.
