#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Smoke: YAML Frontmatter ---"

for f in .opencode/agents/*.md; do
  name=$(basename "$f" .md)

  # Check opening delimiter
  head -1 "$f" | grep -q '^---$' || fail "$name: missing opening ---"

  # Check closing delimiter (find second ---, after first line)
  tail -n +2 "$f" | grep -m1 -n '^---$' | grep -q ':' || fail "$name: missing closing ---"

  # Check required fields
  grep -q "^name: " "$f" || fail "$name: missing 'name' field"
  grep -q "^description: >" "$f" || fail "$name: missing 'description' field"
  grep -q "^mode: subagent" "$f" || fail "$name: missing 'mode: subagent'"
  grep -q "^  task: deny" "$f" || fail "$name: missing 'task: deny'"

  pass "$name: valid frontmatter"
done

echo "--- Smoke: All frontmatter checks passed ---"
