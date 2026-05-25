#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Integration: Lifecycle State Machine ---"

# Derive lifecycle states from ADRs + design doc
# Expected: INIT -> ACTIVE -> REVIEW -> CLOSED -> REOPEN -> ACTIVE

# Check all states are documented
for state in "INIT" "ACTIVE" "REVIEW" "CLOSED" "REOPEN"; do
  grep -q "$state" AGENTS.md \
    && pass "AGENTS.md: lifecycle state $state" \
    || fail "AGENTS.md: missing lifecycle state $state"
done

# Check quality gates for each transition
for transition in "INIT → ACTIVE" "ACTIVE → REVIEW" "REVIEW → CLOSED" "CLOSED → REOPEN"; do
  grep -q "$transition" AGENTS.md \
    && pass "AGENTS.md: transition $transition" \
    || fail "AGENTS.md: missing transition $transition"
done

# Verify lifecycle ADR (ADR-0008)
grep -q "Project Lifecycle" docs/adr/ADR-0008-project-lifecycle.md \
  && pass "ADR-0008: lifecycle documented" || fail "ADR-0008: lifecycle ADR missing or wrong title"

# Verify reopen protocol documented
grep -q "REOPEN" docs/adr/ADR-0008-project-lifecycle.md \
  && pass "ADR-0008: reopen protocol" || fail "ADR-0008: missing reopen protocol"

echo "--- Integration: Lifecycle state machine valid ---"
