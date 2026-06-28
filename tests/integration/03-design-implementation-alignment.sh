#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }


# All ADRs must be referenced in the design doc
for adr in docs/adr/ADR-*.md; do
  adr_num=$(basename "$adr" | grep -oP 'ADR-\d+')
  grep -q "$adr_num" docs/design/README.md \
    && pass "design doc references $adr_num" \
    || fail "design doc missing reference to $adr_num"
done

# All 5 teams must have agent files
for team in architects engineers reviewers testers scribes; do
  [ -f ".opencode/agents/$team.md" ] \
    && pass "team $team has agent file" \
    || fail "team $team missing agent file"
done

# Subagent protocol rules must be in agent frontmatter
for rule in "mode: subagent" "task: deny"; do
  grep -rq "$rule" .opencode/agents/ \
    && pass "agents: $rule defined in all agent files" \
    || fail "agents: $rule missing from some agent files"
done

