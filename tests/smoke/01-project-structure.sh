#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }


# Root files
for f in opencode.json AGENTS.md README.md VERSION.md TODO.md CHANGES.md .gitignore; do
  [ -f "$f" ] && pass "$f exists" || fail "$f missing"
done

# Docs
[ -f docs/design/README.md ] && pass "docs/design/README.md exists" || fail "docs/design/README.md missing"
[ -f docs/adr/README.md ] && pass "docs/adr/README.md exists" || fail "docs/adr/README.md missing"

# ADR files follow ADR-NNNN-*.md pattern
for f in docs/adr/ADR-*.md; do
  [[ "$f" =~ ADR-[0-9]{4}[a-z]?-.+\.md$ ]] && pass "$f matches ADR-NNNN-* pattern" || fail "$f does not match ADR-NNNN-* pattern"
done

# Agent subagents
for agent in architects engineers reviewers testers scribes; do
  [ -f ".opencode/agents/$agent.md" ] && pass ".opencode/agents/$agent.md exists" || fail ".opencode/agents/$agent.md missing"
done

# Reference files
[ -f .opencode/references/kodehold-protocol.md ] && pass "protocol reference exists" || fail "protocol reference missing"

# ICM
[ -f .kodehold-state ] && pass ".kodehold-state exists" || fail ".kodehold-state missing"

