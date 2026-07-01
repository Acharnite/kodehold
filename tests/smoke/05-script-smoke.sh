#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 1. lib/output.sh sources without error
if bash -c 'source scripts/lib/output.sh; pass ok' 2>&1 | grep -q "ok"; then
  pass "lib/output.sh sources without error"
else
  fail "lib/output.sh failed to source"
fi

# 2. gate.sh --list runs without error and lists all 5 transitions
transitions=$(bash "$SCRIPT_DIR/scripts/gate.sh" --list 2>&1)
exit_code=$?
[ "$exit_code" -eq 0 ] && pass "gate.sh --list exits 0" || fail "gate.sh --list exited $exit_code"
for t in INIT_TO_ACTIVE ACTIVE_TO_REVIEW REVIEW_TO_CLOSED CLOSED_TO_REOPEN REOPEN_TO_ACTIVE; do
  echo "$transitions" | grep -q "$t" && pass "gate.sh --list includes $t" || fail "gate.sh --list missing $t"
done

# 3. validate-config.sh runs on valid config
if bash "$SCRIPT_DIR/scripts/validate-config.sh" >/dev/null 2>&1; then
  pass "validate-config.sh passes on config/agents.yaml"
else
  fail "validate-config.sh failed on config/agents.yaml"
fi

# 4. sync-agent-config.sh --help runs
if bash "$SCRIPT_DIR/scripts/sync-agent-config.sh" --help >/dev/null 2>&1; then
  pass "sync-agent-config.sh --help exits 0"
else
  fail "sync-agent-config.sh --help failed"
fi

# 5. token-usage.sh runs without crashing (produces JSON output or error)
output=$(bash "$SCRIPT_DIR/scripts/token-usage.sh" 2>&1 || true)
# If it has access to the DB, output is JSON array. If not, error message.
if echo "$output" | grep -qE '^(\[|\{)' 2>/dev/null || echo "$output" | grep -qi "database not found\|not found"; then
  pass "token-usage.sh runs gracefully"
else
  fail "token-usage.sh produced unexpected output"
fi

# 6. token-report.py --help runs
if python3 "$SCRIPT_DIR/scripts/token-report.py" --help >/dev/null 2>&1; then
  pass "token-report.py --help exits 0"
else
  fail "token-report.py --help failed"
fi

# 7. All scripts are executable
for s in gate.sh ship.sh workspace.sh validate-config.sh sync-agent-config.sh token-usage.sh; do
  if [ -x "$SCRIPT_DIR/scripts/$s" ]; then
    pass "scripts/$s is executable"
  else
    fail "scripts/$s is not executable"
  fi
done
