#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Smoke: ADR Format (Nygard) ---"

for f in docs/adr/ADR-*.md; do
  name=$(basename "$f")
  content=$(cat "$f")

  # Must have Status section
  echo "$content" | grep -q "^## Status" || fail "$name: missing Status section"
  # Status must have a valid value
  echo "$content" | grep -qE "^Accepted|^Proposed|^Deprecated|^Superseded" || fail "$name: invalid Status value"

  # Must have Context section
  echo "$content" | grep -q "^## Context" || fail "$name: missing Context section"

  # Must have Decision section
  echo "$content" | grep -q "^## Decision" || fail "$name: missing Decision section"

  # Must have Consequences section
  echo "$content" | grep -q "^## Consequences" || fail "$name: missing Consequences section"

  pass "$name: valid Nygard format"
done

echo "--- Smoke: All ADR format checks passed ---"
