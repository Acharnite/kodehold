#!/usr/bin/env bash
# Run full KodeHold test suite
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
total=0; passed=0; failed=0

echo "=========================================="
echo "  KodeHold Test Suite"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=========================================="
echo ""

# Smoke tests
echo -e "${YELLOW}━━━ SMOKE TESTS ━━━${NC}"
for t in tests/smoke/*.sh; do
  total=$((total + 1))
  if bash "$t" 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  echo ""
done

# Init tests
echo -e "${YELLOW}━━━ INIT TESTS ━━━${NC}"
for t in tests/init/*.sh; do
  total=$((total + 1))
  if bash "$t" 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  echo ""
done

# Integration tests
echo -e "${YELLOW}━━━ INTEGRATION TESTS ━━━${NC}"
for t in tests/integration/*.sh; do
  total=$((total + 1))
  if bash "$t" 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  echo ""
done

echo "=========================================="
echo -e "  ${GREEN}${passed} passed${NC} / ${RED}${failed} failed${NC} / ${total} total"
echo "=========================================="

[ "$failed" -eq 0 ] || exit 1
