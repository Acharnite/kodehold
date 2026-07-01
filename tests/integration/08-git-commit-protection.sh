#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

ROOT_DIR=$(pwd)
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

setup_project() {
  local project_dir="$1"
  mkdir -p "$project_dir/docs/adr" "$project_dir/docs/design" "$project_dir/.opencode/agents"
  # Write a tracked placeholder in each monitored directory so git tracks the paths
  echo "placeholder" > "$project_dir/docs/adr/.gitkeep"
  echo "placeholder" > "$project_dir/docs/design/.gitkeep"
  echo "placeholder" > "$project_dir/.opencode/agents/.gitkeep"
  cd "$project_dir" && git init --initial-branch=main >/dev/null 2>&1
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A >/dev/null 2>&1
  git commit -m "Initial" >/dev/null 2>&1
  cd "$ROOT_DIR"
}

# ============================================================
# Test 1: Protocol documented in AGENTS.md (director.md)
# ============================================================
echo ""
echo "━━━ Test 1: Commit Protection Protocol documented in AGENTS.md ━━━"
echo ""
if [ -f "$ROOT_DIR/.opencode/agents/director.md" ]; then
  grep -q "Commit Protection Protocol" "$ROOT_DIR/.opencode/agents/director.md" \
    && pass "director.md contains 'Commit Protection Protocol' section" \
    || fail "director.md missing 'Commit Protection Protocol' section"

  grep -q "untracked" "$ROOT_DIR/.opencode/agents/director.md" \
    && pass "director.md mentions 'untracked' files" \
    || fail "director.md does not mention 'untracked' files"

  grep -q "git status --short" "$ROOT_DIR/.opencode/agents/director.md" \
    && pass "director.md references 'git status --short" \
    || fail "director.md missing 'git status --short' reference"
else
  fail "director.md not found at $ROOT_DIR/.opencode/agents/director.md"
fi

# ============================================================
# Test 2: git status detects untracked ADR files
# ============================================================
echo ""
echo "━━━ Test 2: git status detects untracked ADR files ━━━"
echo ""
case_dir="$TMP_ROOT/case_untracked_adr"
setup_project "$case_dir"

# Create a new untracked ADR file
mkdir -p "$case_dir/docs/adr"
touch "$case_dir/docs/adr/ADR-0999-test-protocol.md"

output=$(cd "$case_dir" && git status --short)
echo "$output" | grep -q "?? docs/adr/ADR-0999-test-protocol.md" \
  && pass "Untracked ADR file detected via git status --short" \
  || fail "git status --short did not detect untracked ADR file"

# ============================================================
# Test 3: git status detects untracked design doc changes
# ============================================================
echo ""
echo "━━━ Test 3: git status detects design doc modifications ━━━"
echo ""
case_dir="$TMP_ROOT/case_modified_design"
setup_project "$case_dir"

# Create and commit an initial design doc, then modify it
mkdir -p "$case_dir/docs/design"
echo "# Design Doc" > "$case_dir/docs/design/README.md"
(cd "$case_dir" && git add -A && git commit -m "Add design doc" >/dev/null 2>&1)

# Modify the design doc
echo "# Design Doc - Updated" > "$case_dir/docs/design/README.md"

output=$(cd "$case_dir" && git status --short)
echo "$output" | grep -q "M docs/design/README.md" \
  && pass "Modified design doc detected via git status --short" \
  || fail "git status --short did not detect modified design doc"

# ============================================================
# Test 4: git status detects untracked agent files
# ============================================================
echo ""
echo "━━━ Test 4: git status detects untracked agent files ━━━"
echo ""
case_dir="$TMP_ROOT/case_untracked_agent"
setup_project "$case_dir"

# Create a new untracked agent file
mkdir -p "$case_dir/.opencode/agents"
touch "$case_dir/.opencode/agents/custom-agent.md"

output=$(cd "$case_dir" && git status --short)
echo "$output" | grep -q "?? .opencode/agents/custom-agent.md" \
  && pass "Untracked agent file detected via git status --short" \
  || fail "git status --short did not detect untracked agent file"

# ============================================================
# Test 5: git status shows nothing for clean repo
# ============================================================
echo ""
echo "━━━ Test 5: git status shows nothing for clean repo ━━━"
echo ""
case_dir="$TMP_ROOT/case_clean_repo"
setup_project "$case_dir"

output=$(cd "$case_dir" && git status --short)
[ -z "$output" ] \
  && pass "Clean repo shows no untracked or modified files" \
  || fail "Clean repo unexpectedly shows: $output"

# ============================================================
# Test 6: Graceful degradation when monitored dirs don't exist
# ============================================================
echo ""
echo "━━━ Test 6: Graceful degradation for non-existent paths ━━━"
echo ""
case_dir="$TMP_ROOT/case_missing_dirs"
mkdir -p "$case_dir"
cd "$case_dir" && git init --initial-branch=main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
git commit -m "Initial" --allow-empty >/dev/null 2>&1
cd "$ROOT_DIR"

# Run git status --short — should succeed even though
# docs/adr/, docs/design/, .opencode/agents/ don't exist yet
output=$(cd "$case_dir" && git status --short 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ] \
  && pass "git status --short succeeds when monitored dirs are absent" \
  || fail "git status --short failed (rc=$rc) when monitored dirs are absent"

# Verify no errors about missing paths
echo "$output" | grep -qi "error" \
  && fail "git status --short produced errors for missing directories" \
  || pass "git status --short produces no errors for missing directories"

# ============================================================
# Summary
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}All commit protection tests pass${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
