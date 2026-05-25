#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Init: Configuration Validation ---"

# opencode.json must be valid JSON
python3 -c "import json; json.load(open('opencode.json'))" 2>/dev/null \
  && pass "opencode.json: valid JSON" || fail "opencode.json: invalid JSON"

# opencode.json must have Ollama provider available
python3 -c "
import json
c = json.load(open('opencode.json'))
assert 'provider' in c and 'ollama' in c['provider'], 'missing Ollama provider'
" && pass "opencode.json: has Ollama provider configured" \
  || fail "opencode.json: missing Ollama provider"

# .gitignore must exist and contain .icm/
grep -q "^\.icm/$" .gitignore && pass ".gitignore: ignores .icm/" || fail ".gitignore: missing .icm/"

# VERSION.md must have current version
grep -q "^| 0\.2\.0 " VERSION.md && pass "VERSION.md: version 0.2.0 found" || fail "VERSION.md: version 0.2.0 not found"

# CHANGES.md must have latest entry
grep -q "^## 0\.2\.0 " CHANGES.md && pass "CHANGES.md: changelog entry for 0.2.0" || fail "CHANGES.md: missing 0.2.0"

# AGENTS.md must reference all 5 teams
for team in architects engineers reviewers testers scribes; do
  grep -qi "$team" AGENTS.md && pass "AGENTS.md: references $team" || fail "AGENTS.md: missing $team"
done

echo "--- Init: All config checks passed ---"
