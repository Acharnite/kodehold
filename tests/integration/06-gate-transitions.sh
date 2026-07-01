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

  mkdir -p "$project_dir/scripts" "$project_dir/scripts/lib" \
           "$project_dir/docs/design" "$project_dir/docs/adr" \
           "$project_dir/docs/decisions" "$project_dir/tests"
  cp "$ROOT_DIR/scripts/gate.sh" "$project_dir/scripts/gate.sh"
  cp "$ROOT_DIR/scripts/lib/output.sh" "$project_dir/scripts/lib/output.sh"

  # Default passing test runner
  cat > "$project_dir/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "All tests pass"
exit 0
EOF
  chmod +x "$project_dir/tests/run.sh"

  # Minimal design doc with Status: Active and Last Updated
  cat > "$project_dir/docs/design/README.md" <<'EOF'
# Design
Status: Active
Last Updated: 2026-06-28

## Purpose & Scope
## Requirements
EOF

  # Minimal ADR
  cat > "$project_dir/docs/adr/README.md" <<'EOF'
# ADR Index
EOF
  cat > "$project_dir/docs/adr/ADR-0001-sample.md" <<'EOF'
# ADR-0001: Sample
EOF
}

# ============================================================
# ACTIVE_TO_REVIEW
# ============================================================

# --- Test 1: ACTIVE_TO_REVIEW missing .testers_done ---
case_dir="$TMP_ROOT/case_atr_missing_testers"
setup_project "$case_dir"
touch "$case_dir/.code_reviewed"

if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition ACTIVE_TO_REVIEW >"out.log" 2>&1); then
  fail "ACTIVE_TO_REVIEW should fail without .testers_done"
fi
grep -q "Testers did not complete" "$case_dir/out.log" \
  && pass "ACTIVE_TO_REVIEW enforces .testers_done" \
  || fail "ACTIVE_TO_REVIEW missing .testers_done enforcement message"

# --- Test 2: ACTIVE_TO_REVIEW missing .code_reviewed ---
case_dir="$TMP_ROOT/case_atr_missing_codereview"
setup_project "$case_dir"
touch "$case_dir/.testers_done"

if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition ACTIVE_TO_REVIEW >"out.log" 2>&1); then
  fail "ACTIVE_TO_REVIEW should fail without .code_reviewed"
fi
grep -q "Code not reviewed" "$case_dir/out.log" \
  && pass "ACTIVE_TO_REVIEW enforces .code_reviewed" \
  || fail "ACTIVE_TO_REVIEW missing .code_reviewed enforcement message"

# --- Test 3: ACTIVE_TO_REVIEW all markers present + cleanup ---
case_dir="$TMP_ROOT/case_atr_all_markers"
setup_project "$case_dir"
touch "$case_dir/.testers_done" "$case_dir/.code_reviewed"

(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition ACTIVE_TO_REVIEW >"out.log" 2>&1) \
  && pass "ACTIVE_TO_REVIEW passes with all markers" \
  || fail "ACTIVE_TO_REVIEW should pass with .testers_done and .code_reviewed"

[ ! -f "$case_dir/.testers_done" ] \
  && pass ".testers_done cleaned after ACTIVE_TO_REVIEW" \
  || fail ".testers_done not cleaned after successful ACTIVE_TO_REVIEW"

[ ! -f "$case_dir/.code_reviewed" ] \
  && pass ".code_reviewed cleaned after ACTIVE_TO_REVIEW" \
  || fail ".code_reviewed not cleaned after successful ACTIVE_TO_REVIEW"

# ============================================================
# REVIEW_TO_CLOSED
# ============================================================

# --- Test 4: REVIEW_TO_CLOSED test failure ---
case_dir="$TMP_ROOT/case_rtc_test_failure"
setup_project "$case_dir"

# Override run.sh to fail
cat > "$case_dir/tests/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "Tests failing"
exit 1
EOF

if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition REVIEW_TO_CLOSED >"out.log" 2>&1); then
  fail "REVIEW_TO_CLOSED should fail when tests fail"
fi
grep -q "Test suite has failures" "$case_dir/out.log" \
  && pass "REVIEW_TO_CLOSED enforces passing tests" \
  || fail "REVIEW_TO_CLOSED missing test failure message"

# --- Test 5: REVIEW_TO_CLOSED all pass ---
case_dir="$TMP_ROOT/case_rtc_all_pass"
setup_project "$case_dir"

(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition REVIEW_TO_CLOSED >"out.log" 2>&1) \
  && pass "REVIEW_TO_CLOSED passes with all conditions met" \
  || fail "REVIEW_TO_CLOSED should pass with tests green and design doc present"

# Verify marker cleanup — REVIEW_TO_CLOSED queues all 6 markers for removal
[ ! -f "$case_dir/.design_reviewed" ] \
  && pass ".design_reviewed cleaned after REVIEW_TO_CLOSED" \
  || fail ".design_reviewed not cleaned after REVIEW_TO_CLOSED"
[ ! -f "$case_dir/.testers_done" ] \
  && pass ".testers_done cleaned after REVIEW_TO_CLOSED" \
  || fail ".testers_done not cleaned after REVIEW_TO_CLOSED"
[ ! -f "$case_dir/.impact_analysis_done" ] \
  && pass ".impact_analysis_done cleaned after REVIEW_TO_CLOSED" \
  || fail ".impact_analysis_done not cleaned after REVIEW_TO_CLOSED"
[ ! -f "$case_dir/.code_reviewed" ] \
  && pass ".code_reviewed cleaned after REVIEW_TO_CLOSED" \
  || fail ".code_reviewed not cleaned after REVIEW_TO_CLOSED"
[ ! -f "$case_dir/.second_opinion_done" ] \
  && pass ".second_opinion_done cleaned after REVIEW_TO_CLOSED" \
  || fail ".second_opinion_done not cleaned after REVIEW_TO_CLOSED"
[ ! -f "$case_dir/.team_meeting_done" ] \
  && pass ".team_meeting_done cleaned after REVIEW_TO_CLOSED" \
  || fail ".team_meeting_done not cleaned after REVIEW_TO_CLOSED"

# Verify .distill_needed is created
[ -f "$case_dir/.distill_needed" ] \
  && pass ".distill_needed created after REVIEW_TO_CLOSED" \
  || fail ".distill_needed not created after successful REVIEW_TO_CLOSED"

# ============================================================
# CLOSED_TO_REOPEN
# ============================================================

# --- Test 6: CLOSED_TO_REOPEN missing .impact_analysis_done ---
case_dir="$TMP_ROOT/case_ctr_missing_impact"
setup_project "$case_dir"

if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition CLOSED_TO_REOPEN >"out.log" 2>&1); then
  fail "CLOSED_TO_REOPEN should fail without .impact_analysis_done"
fi
grep -q "Impact analysis not completed" "$case_dir/out.log" \
  && pass "CLOSED_TO_REOPEN enforces .impact_analysis_done" \
  || fail "CLOSED_TO_REOPEN missing .impact_analysis_done enforcement message"

# --- Test 7: CLOSED_TO_REOPEN with marker + cleanup ---
case_dir="$TMP_ROOT/case_ctr_with_marker"
setup_project "$case_dir"
touch "$case_dir/.impact_analysis_done"

(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition CLOSED_TO_REOPEN >"out.log" 2>&1) \
  && pass "CLOSED_TO_REOPEN passes with .impact_analysis_done" \
  || fail "CLOSED_TO_REOPEN should pass with .impact_analysis_done"

[ ! -f "$case_dir/.impact_analysis_done" ] \
  && pass ".impact_analysis_done cleaned after CLOSED_TO_REOPEN" \
  || fail ".impact_analysis_done not cleaned after successful CLOSED_TO_REOPEN"

# ============================================================
# REOPEN_TO_ACTIVE
# ============================================================

# --- Test 8: REOPEN_TO_ACTIVE missing .second_opinion_done ---
case_dir="$TMP_ROOT/case_rta_missing_second_opinion"
setup_project "$case_dir"

if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition REOPEN_TO_ACTIVE >"out.log" 2>&1); then
  fail "REOPEN_TO_ACTIVE should fail without .second_opinion_done"
fi
grep -q "Second opinion not completed" "$case_dir/out.log" \
  && pass "REOPEN_TO_ACTIVE enforces .second_opinion_done" \
  || fail "REOPEN_TO_ACTIVE missing .second_opinion_done enforcement message"

# --- Test 9: REOPEN_TO_ACTIVE with marker + cleanup ---
case_dir="$TMP_ROOT/case_rta_with_marker"
setup_project "$case_dir"
touch "$case_dir/.second_opinion_done"

(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition REOPEN_TO_ACTIVE >"out.log" 2>&1) \
  && pass "REOPEN_TO_ACTIVE passes with .second_opinion_done" \
  || fail "REOPEN_TO_ACTIVE should pass with .second_opinion_done"

[ ! -f "$case_dir/.second_opinion_done" ] \
  && pass ".second_opinion_done cleaned after REOPEN_TO_ACTIVE" \
  || fail ".second_opinion_done not cleaned after successful REOPEN_TO_ACTIVE"
