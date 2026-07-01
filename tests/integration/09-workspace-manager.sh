#!/usr/bin/env bash
# Integration test: workspace manager (scripts/workspace.sh)
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

ROOT_DIR=$(pwd)
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

# Set up git config for the test session so git commits don't fail
export GIT_AUTHOR_NAME="TestRunner"
export GIT_AUTHOR_EMAIL="test@kodehold.test"
export GIT_COMMITTER_NAME="TestRunner"
export GIT_COMMITTER_EMAIL="test@kodehold.test"

setup_workspace_root() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/scripts/lib" "$root/workspaces"
  cp "$ROOT_DIR/scripts/workspace.sh" "$root/scripts/workspace.sh"
  cp "$ROOT_DIR/scripts/lib/output.sh" "$root/scripts/lib/output.sh"
  cp "$ROOT_DIR/scripts/gate.sh" "$root/scripts/gate.sh"
}

# ============================================================
# Test 1: init creates workspace structure
# ============================================================
echo ""
echo "━━━ Test 1: init creates workspace structure ━━━"
echo ""
case_dir="$TMP_ROOT/case_init_structure"
setup_workspace_root "$case_dir"

# Pipe empty input to skip the interactive remote prompt
echo "" | bash "$case_dir/scripts/workspace.sh" init my-project >"$case_dir/out.log" 2>&1

[ -d "$case_dir/workspaces/my-project" ] \
  && pass "init: workspace directory created" \
  || fail "init: workspace directory missing"

[ -f "$case_dir/workspaces/my-project/.kodehold-state" ] \
  && pass "init: .kodehold-state created" \
  || fail "init: .kodehold-state missing"

[ -f "$case_dir/workspaces/my-project/docs/design/README.md" ] \
  && pass "init: docs/design/README.md created" \
  || fail "init: docs/design/README.md missing"

[ -f "$case_dir/workspaces/my-project/docs/adr/README.md" ] \
  && pass "init: docs/adr/README.md created" \
  || fail "init: docs/adr/README.md missing"

[ -d "$case_dir/workspaces/my-project/src" ] \
  && pass "init: src/ created" \
  || fail "init: src/ missing"

[ -d "$case_dir/workspaces/my-project/tests" ] \
  && pass "init: tests/ created" \
  || fail "init: tests/ missing"

[ -f "$case_dir/workspaces/my-project/.gitignore" ] \
  && pass "init: .gitignore created" \
  || fail "init: .gitignore missing"

[ -d "$case_dir/workspaces/my-project/.git" ] \
  && pass "init: .git/ initialized" \
  || fail "init: .git/ missing"

# ============================================================
# Test 2: init rejects invalid slug
# ============================================================
echo ""
echo "━━━ Test 2: init rejects invalid slug ━━━"
echo ""
case_dir="$TMP_ROOT/case_init_invalid_slug"
setup_workspace_root "$case_dir"

if echo "" | bash "$case_dir/scripts/workspace.sh" init "My Project" >"$case_dir/out.log" 2>&1; then
  fail "init: should reject invalid slug 'My Project'"
fi
grep -q "Invalid workspace name" "$case_dir/out.log" \
  && pass "init: rejects invalid slug" \
  || fail "init: missing rejection message for invalid slug"

# ============================================================
# Test 3: init rejects duplicate
# ============================================================
echo ""
echo "━━━ Test 3: init rejects duplicate ━━━"
echo ""
case_dir="$TMP_ROOT/case_init_duplicate"
setup_workspace_root "$case_dir"

echo "" | bash "$case_dir/scripts/workspace.sh" init test-project >"$case_dir/out.log" 2>&1

if echo "" | bash "$case_dir/scripts/workspace.sh" init test-project >"$case_dir/out2.log" 2>&1; then
  fail "init: should reject duplicate workspace name"
fi
grep -q "already exists" "$case_dir/out2.log" \
  && pass "init: rejects duplicate workspace name" \
  || fail "init: missing rejection message for duplicate"

# ============================================================
# Test 4: adopt creates symlink with ADOPTED=true
# ============================================================
echo ""
echo "━━━ Test 4: adopt creates symlink with ADOPTED=true ━━━"
echo ""
case_dir="$TMP_ROOT/case_adopt_symlink"
setup_workspace_root "$case_dir"

# Create a real project to adopt
target="$case_dir/adopt-source"
mkdir -p "$target"
echo '{"name":"test-project"}' > "$target/package.json"

echo "" | bash "$case_dir/scripts/workspace.sh" adopt my-adopted "$target" >"$case_dir/out.log" 2>&1

[ -L "$case_dir/workspaces/my-adopted" ] \
  && pass "adopt: symlink created" \
  || fail "adopt: symlink not found"

[ -f "$case_dir/workspaces/my-adopted/.kodehold-state" ] \
  && pass "adopt: .kodehold-state created" \
  || fail "adopt: .kodehold-state missing"

grep -q "ADOPTED=true" "$case_dir/workspaces/my-adopted/.kodehold-state" \
  && pass "adopt: ADOPTED=true in .kodehold-state" \
  || fail "adopt: ADOPTED=true missing from .kodehold-state"

grep -q "JavaScript" "$case_dir/out.log" \
  && pass "adopt: detected JavaScript/TypeScript language" \
  || fail "adopt: JavaScript language detection failed"

# ============================================================
# Test 5: adopt validates target exists
# ============================================================
echo ""
echo "━━━ Test 5: adopt validates target exists ━━━"
echo ""
case_dir="$TMP_ROOT/case_adopt_nonexistent"
setup_workspace_root "$case_dir"

if bash "$case_dir/scripts/workspace.sh" adopt nonexistent /path/does/not/exist >"$case_dir/out.log" 2>&1; then
  fail "adopt: should reject non-existent target path"
fi
grep -q "Target path does not exist" "$case_dir/out.log" \
  && pass "adopt: rejects non-existent target path" \
  || fail "adopt: missing rejection message for non-existent target"

# ============================================================
# Test 6: state shows STATE=INIT
# ============================================================
echo ""
echo "━━━ Test 6: state shows STATE=INIT ━━━"
echo ""
case_dir="$TMP_ROOT/case_state_show"
setup_workspace_root "$case_dir"

echo "" | bash "$case_dir/scripts/workspace.sh" init state-project >"$case_dir/out.log" 2>&1
bash "$case_dir/scripts/workspace.sh" state state-project >"$case_dir/out2.log" 2>&1

grep -q "STATE=INIT" "$case_dir/out2.log" \
  && pass "state: shows STATE=INIT" \
  || fail "state: STATE=INIT not found in output"

# ============================================================
# Test 7: deploy-ready checks CLOSED
# ============================================================
echo ""
echo "━━━ Test 7: deploy-ready checks CLOSED ━━━"
echo ""
case_dir="$TMP_ROOT/case_deploy_ready"
setup_workspace_root "$case_dir"

echo "" | bash "$case_dir/scripts/workspace.sh" init deploy-project >"$case_dir/out.log" 2>&1

set +e
bash "$case_dir/scripts/workspace.sh" deploy-ready deploy-project >"$case_dir/out2.log" 2>&1
exit_code=$?
set -e

[ "$exit_code" -eq 1 ] \
  && pass "deploy-ready: exits with code 1 for INIT state" \
  || fail "deploy-ready: expected exit code 1, got $exit_code"

grep -q "must reach CLOSED before deploy" "$case_dir/out2.log" \
  && pass "deploy-ready: shows 'must reach CLOSED before deploy'" \
  || fail "deploy-ready: missing 'must reach CLOSED' message"

# ============================================================
# Test 8: ensure-git backfills after .git removal
# ============================================================
echo ""
echo "━━━ Test 8: ensure-git backfills after .git removal ━━━"
echo ""
case_dir="$TMP_ROOT/case_ensure_git"
setup_workspace_root "$case_dir"

echo "" | bash "$case_dir/scripts/workspace.sh" init ensure-test >"$case_dir/out.log" 2>&1

# Remove .git to simulate backfill scenario
rm -rf "$case_dir/workspaces/ensure-test/.git"

echo "" | bash "$case_dir/scripts/workspace.sh" ensure-git ensure-test >"$case_dir/out2.log" 2>&1

[ -d "$case_dir/workspaces/ensure-test/.git" ] \
  && pass "ensure-git: .git directory recreated" \
  || fail "ensure-git: .git directory still missing"

grep -q "Git repository initialized" "$case_dir/out2.log" \
  && pass "ensure-git: reports 'Git repository initialized'" \
  || fail "ensure-git: missing 'Git repository initialized' message"

# ============================================================
# Summary
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}All workspace manager tests pass${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
