#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }


for f in docs/adr/ADR-*.md; do
  [[ "$f" == *.original.md ]] && continue
  name=$(basename "$f")

  # Must have Status section
  grep -q "^## Status" "$f" || fail "$name: missing Status section"
  # Status must have a valid value
  grep -qE "^Accepted|^Proposed|^Deprecated|^Superseded" "$f" || fail "$name: invalid Status value"

  # Must have Context section
  grep -q "^## Context" "$f" || fail "$name: missing Context section"

  # Must have Decision section
  grep -q "^## Decision" "$f" || fail "$name: missing Decision section"

  # Must have Consequences section
  grep -q "^## Consequences" "$f" || fail "$name: missing Consequences section"

  pass "$name: valid Nygard format"
done

