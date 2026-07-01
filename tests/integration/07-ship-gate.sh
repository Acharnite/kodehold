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
  mkdir -p "$project_dir/tests" "$project_dir/scripts"
  mkdir -p "$project_dir/scripts/lib"
  cp "$ROOT_DIR/scripts/ship.sh" "$project_dir/scripts/ship.sh"
  cp "$ROOT_DIR/scripts/lib/output.sh" "$project_dir/scripts/lib/output.sh"

  # Default VERSION.md
  cat > "$project_dir/VERSION.md" <<'EOF'
| 0.2.0 |
EOF

  # Default CHANGES.md
  cat > "$project_dir/CHANGES.md" <<'EOF'
# Changelog

## 0.2.0 — 2026-06-28
### Fixed
- Initial fixes
EOF

  # Default TODO.md
  cat > "$project_dir/TODO.md" <<'EOF'
# TODOs
EOF

  # Default tests/run.sh
  cat > "$project_dir/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "All tests pass"
exit 0
EOF
  chmod +x "$project_dir/tests/run.sh"
}

# ============================================================
# Test 1: Missing VERSION.md
# ============================================================
echo ""
echo "━━━ Test: ship.sh missing VERSION.md ━━━"
echo ""
case_dir="$TMP_ROOT/case_missing_version"
setup_project "$case_dir"
rm "$case_dir/VERSION.md"

if (cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1); then
  fail "ship.sh should fail when VERSION.md is missing"
fi
grep -q "VERSION.md not found" "$case_dir/out.log" \
  && pass "Detects missing VERSION.md" \
  || fail "Missing VERSION.md error message not found"

# ============================================================
# Test 2: Missing CHANGES.md
# ============================================================
echo ""
echo "━━━ Test: ship.sh missing CHANGES.md ━━━"
echo ""
case_dir="$TMP_ROOT/case_missing_changes"
setup_project "$case_dir"
rm "$case_dir/CHANGES.md"

if (cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1); then
  fail "ship.sh should fail when CHANGES.md is missing"
fi
grep -q "CHANGES.md not found" "$case_dir/out.log" \
  && pass "Detects missing CHANGES.md" \
  || fail "Missing CHANGES.md error message not found"

# ============================================================
# Test 3: Missing TODO.md
# ============================================================
echo ""
echo "━━━ Test: ship.sh missing TODO.md ━━━"
echo ""
case_dir="$TMP_ROOT/case_missing_todo"
setup_project "$case_dir"
rm "$case_dir/TODO.md"

if (cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1); then
  fail "ship.sh should fail when TODO.md is missing"
fi
grep -q "TODO.md not found" "$case_dir/out.log" \
  && pass "Detects missing TODO.md" \
  || fail "Missing TODO.md error message not found"

# ============================================================
# Test 4: Version mismatch between VERSION.md and CHANGES.md
# ============================================================
echo ""
echo "━━━ Test: ship.sh version mismatch ━━━"
echo ""
case_dir="$TMP_ROOT/case_version_mismatch"
setup_project "$case_dir"

# Override VERSION.md with a different version than CHANGES.md
cat > "$case_dir/VERSION.md" <<'EOF'
| 1.0.0 |
EOF

if (cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1); then
  fail "ship.sh should fail when versions mismatch"
fi
grep -q "No entry for v1.0.0" "$case_dir/out.log" \
  && pass "Detects version mismatch" \
  || fail "Version mismatch error message not found"

# ============================================================
# Test 5: All checks pass
# ============================================================
echo ""
echo "━━━ Test: ship.sh all checks pass ━━━"
echo ""
case_dir="$TMP_ROOT/case_all_pass"
setup_project "$case_dir"

# Initialize git repo so git checks pass
git -C "$case_dir" init --initial-branch=main >/dev/null 2>&1
git -C "$case_dir" config user.email "test@test.com"
git -C "$case_dir" config user.name "Test"
git -C "$case_dir" add -A >/dev/null 2>&1
git -C "$case_dir" commit -m "initial" >/dev/null 2>&1

(cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1) \
  && pass "All checks pass" \
  || fail "ship.sh should pass when all conditions are met"
grep -q "Pre-ship Checks Passed" "$case_dir/out.log" \
  && pass "Pre-ship Checks Passed message found" \
  || fail "Pre-ship Checks Passed message not found"

# ============================================================
# Test 6: Tests fail
# ============================================================
echo ""
echo "━━━ Test: ship.sh tests fail ━━━"
echo ""
case_dir="$TMP_ROOT/case_tests_fail"
setup_project "$case_dir"

# Override tests/run.sh to fail
cat > "$case_dir/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "Tests failing"
exit 1
EOF
chmod +x "$case_dir/tests/run.sh"

if (cd "$case_dir" && bash "scripts/ship.sh" >"out.log" 2>&1); then
  fail "ship.sh should fail when tests fail"
fi
grep -q "Test suite failed" "$case_dir/out.log" \
  && pass "Detects test failure" \
  || fail "Test failure message not found"

# ============================================================
# Summary
# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}All ship gate tests pass${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
