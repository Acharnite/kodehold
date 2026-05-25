#!/usr/bin/env bash
# KodeHold Shipping Gate — run before every push, PR, or release
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

echo ""
echo "=========================================="
echo "  KodeHold Shipping Gate"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=========================================="
echo ""

# 1. Version check
echo "--- Step 1: Version Check ---"
if [ ! -f VERSION.md ]; then
  fail "VERSION.md not found"
fi
current_ver=$(grep -oP '(?<=^\| )\d+\.\d+\.\d+(?= \|)' VERSION.md | head -1)
[ -n "$current_ver" ] && pass "Current version: $current_ver" || fail "Could not parse version from VERSION.md"
echo ""

# 2. CHANGES.md check
echo "--- Step 2: CHANGES.md ---"
if [ ! -f CHANGES.md ]; then
  fail "CHANGES.md not found"
fi
grep -q "^## $current_ver " CHANGES.md 2>/dev/null || warn "No entry for v$current_ver in CHANGES.md — add one"
echo ""

# 3. TODO.md check
echo "--- Step 3: TODO.md ---"
[ -f TODO.md ] && pass "TODO.md exists" || fail "TODO.md not found"
echo ""

# 4. Test suite
echo "--- Step 4: Test Suite ---"
if [ -f tests/run.sh ]; then
  if bash tests/run.sh; then
    pass "All tests pass"
  else
    fail "Test suite failed — fix before shipping"
  fi
else
  fail "tests/run.sh not found"
fi
echo ""

# 5. ICM store check
echo "--- Step 5: ICM Check ---"
if command -v icm &>/dev/null; then
  icm stats --db .icm/memories.db &>/dev/null \
    && pass "ICM database accessible" \
    || warn "ICM database not accessible — run icm store for this release"
else
  warn "ICM not installed — skip ICM check"
fi
echo ""

# 6. Git status
echo "--- Step 6: Git Status ---"
if git diff --stat --cached | grep -q .; then
  pass "Changes staged for commit"
elif git diff --stat | grep -q .; then
  warn "Unstaged changes exist — stage them before committing"
else
  # Check for untracked files
  if git ls-files --others --exclude-standard | grep -q .; then
    warn "Untracked files exist — check git status"
  fi
fi
echo ""

# 7. PR check
echo "--- Step 7: Branch Check ---"
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]; then
  pass "On main branch — direct push"
else
  warn "On branch '$branch' — remember to create PR: gh pr create"
fi
echo ""

echo "=========================================="
echo -e "  ${GREEN}Shipping Gate Complete${NC}"
echo "  Ready to commit, push, and tag"
echo "=========================================="
echo ""
echo "Suggested commit format:"
echo "  <type>(<scope>): <description>"
echo ""
echo "Types: feat, fix, docs, test, refactor, chore"
echo "Scope: core, agents, docs, tests, config, release"
echo ""
echo "Tag (releases only):"
echo "  git tag v$current_ver && git push origin v$current_ver"
