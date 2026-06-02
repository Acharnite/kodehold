#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Init: ADR Index Integrity ---"

index="docs/adr/README.md"
[ -f "$index" ] || fail "ADR index not found"

# Every ADR file must be listed in the index
for f in docs/adr/ADR-*.md; do
  [[ "$f" == *.original.md ]] && continue
  adr_name=$(basename "$f" .md)
  grep -q "$adr_name" "$index" \
    && pass "$adr_name: indexed" \
    || fail "$adr_name: missing from index"
done

# Index must have correct table headers
head -1 "$index" | grep -q "Architecture Decision Log" \
  && pass "index: has title" || fail "index: missing title"

# Table headers must be present
grep -q "| ADR | Title | Status | Date |" "$index" \
  && pass "index: has table headers" || fail "index: missing table headers"

echo "--- Init: All ADR index checks passed ---"
