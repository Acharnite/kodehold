#!/usr/bin/env bash
# Run KodeHold test suite
# Usage: bash tests/run.sh [section]
#   section: smoke | init | integration | yaml | all (default)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
total=0; passed=0; failed=0
SECTION="${1:-all}"

run_section() {
  local label="$1"; shift
  echo -e "${YELLOW}━━━ ${label} TESTS ━━━${NC}"
  for t in "$@"; do
    [ -f "$t" ] || continue
    total=$((total + 1))
    echo "  ${label}: $(basename "$t" .sh)..."
    if bash "$t" 2>&1; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
    echo ""
  done
}

run_yaml_tests() {
  echo -e "${YELLOW}━━━ YAML CONFIG TESTS ━━━${NC}"
  if ! python3 -c "import yaml, jsonschema" 2>/dev/null; then
    echo "  Skipping YAML tests (pyyaml/jsonschema not installed)"
    echo ""
    return
  fi
  total=$((total + 1))
  echo "  yaml: test_yaml_config..."
  if python3 -m pytest tests/init/test_yaml_config.py -v 2>&1; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  echo ""
}

echo "=========================================="
echo "  KodeHold Test Suite"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "  Section: ${SECTION}"
echo "=========================================="
echo ""

case "$SECTION" in
  all)
    run_section "Smoke" tests/smoke/*.sh
    run_section "Init" tests/init/*.sh
    run_section "Integration" tests/integration/*.sh
    run_yaml_tests
    ;;
  smoke)
    run_section "Smoke" tests/smoke/*.sh
    ;;
  init)
    run_section "Init" tests/init/*.sh
    ;;
  integration)
    run_section "Integration" tests/integration/*.sh
    ;;
  yaml)
    run_yaml_tests
    ;;
  *)
    echo "Unknown section: $SECTION"
    echo "Usage: bash tests/run.sh [smoke|init|integration|yaml|all]"
    exit 1
    ;;
esac

echo "=========================================="
echo -e "  ${GREEN}${passed} passed${NC} / ${RED}${failed} failed${NC} / ${total} total"
echo "=========================================="

[ "$failed" -eq 0 ] || exit 1
