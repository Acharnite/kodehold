#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Init: ICM Connectivity ---"

# ICM must be installed
command -v icm >/dev/null 2>&1 && pass "icm binary found" || fail "icm binary not found"

# ICM must work with the project DB
icm stats --db .icm/memories.db >/dev/null 2>&1 \
  && pass "icm stats: database accessible" \
  || fail "icm stats: database not accessible"

# Must have memories
mem_count=$(icm stats --db .icm/memories.db 2>/dev/null | grep "Memories:" | awk '{print $2}')
[ -n "$mem_count" ] && [ "$mem_count" -gt 0 ] \
  && pass "icm: $mem_count memories stored" \
  || fail "icm: no memories found"

# Must have memoirs
memoir_count=$(icm memoir list --db .icm/memories.db 2>/dev/null | tail -n +2 | wc -l)
[ "$memoir_count" -ge 5 ] \
  && pass "icm: $memoir_count memoirs" \
  || fail "icm: expected >=5 memoirs, found $memoir_count"

echo "--- Init: All ICM checks passed ---"
