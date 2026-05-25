#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; }

echo "--- Init: ICM Connectivity ---"

# ICM must be installed
command -v icm >/dev/null 2>&1 && pass "icm binary found" || fail "icm binary not found"

# Create DB if not present (CI bootstrap)
if [ ! -f .icm/memories.db ]; then
  warn "memories.db not found — attempting bootstrap"
  mkdir -p .icm
  icm store --db .icm/memories.db -t kodehold-bootstrap -i low -k "bootstrap" -c "Bootstrap memory" >/dev/null 2>&1 \
    && pass "icm: database bootstrapped" \
    || fail "icm: could not bootstrap database"
fi

# ICM must work with the project DB
icm stats --db .icm/memories.db >/dev/null 2>&1 \
  && pass "icm stats: database accessible" \
  || fail "icm stats: database not accessible"

# Must have memories (>0)
mem_count=$(icm stats --db .icm/memories.db 2>/dev/null | grep "Memories:" | awk '{print $2}')
[ -n "$mem_count" ] && [ "$mem_count" -gt 0 ] \
  && pass "icm: $mem_count memories stored" \
  || warn "icm: no memories found (expected in dev, acceptable in fresh CI)"

# Must have memoirs (>0)
memoir_count=$(icm memoir list --db .icm/memories.db 2>/dev/null | tail -n +2 | wc -l)
[ "$memoir_count" -ge 1 ] \
  && pass "icm: $memoir_count memoirs" \
  || warn "icm: no memoirs (expected in dev, acceptable in fresh CI)"

echo "--- Init: All ICM checks passed ---"
