#!/usr/bin/env bash
# KodeHold Lifecycle Gate — run automated quality checks before state transitions
set -euo pipefail
source "$(dirname "$0")/lib/output.sh"

STATE_FILE=".kodehold-state"
DESIGN_DOC="docs/design/README.md"
ADR_DIR="docs/adr"
TEST_RUNNER="tests/run.sh"

gate_failed=0
cleanup_markers=()
validate_only=false
reviewer_mode=false
PROJECT_PATH=""
show_status=false
declare -A check_results
check() {
  if ! "$@" >/dev/null 2>&1; then
    fail "$1 failed"
    gate_failed=1
  fi
}

queue_cleanup_marker() {
  cleanup_markers+=("$1")
}

record_check() {
  local name="$1"
  local result="$2"
  check_results["$name"]="$result"
}

cleanup_markers_on_pass() {
  if [ "${#cleanup_markers[@]}" -eq 0 ]; then
    return
  fi

  rm -f "${cleanup_markers[@]}"
  pass "Lifecycle markers cleaned up: ${cleanup_markers[*]}"
}

is_noninteractive() {
  case "${OPENCODE_NONINTERACTIVE:-}" in
    true|TRUE|1|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

assert_file() {
  if [ -f "$1" ]; then
    pass "$1 exists"
  else
    fail "$1 not found"
    gate_failed=1
  fi
}

assert_dir() {
  if [ -d "$1" ]; then
    pass "$1 exists"
  else
    fail "$1 not found"
    gate_failed=1
  fi
}

init_to_active() {
  echo ""
  echo "━━━ Gate: INIT → ACTIVE ━━━"
  echo ""

  # Check if this is an adopted project (already has code, relaxed requirements)
  local adopted=false
  if [ -f "$STATE_FILE" ] && grep -q "ADOPTED=true" "$STATE_FILE" 2>/dev/null; then
    adopted=true
    info "Adopted project detected — relaxing INIT→ACTIVE checks"
  fi

  # Design doc exists and has all 11 sections
  assert_file "$DESIGN_DOC"
  for section in "Purpose & Scope" "Requirements" "Architecture Overview" "Component Design" "Data Model" "API Design" "Testing Strategy" "ADR Index" "Open Questions" "Changelog"; do
    if grep -q "$section" "$DESIGN_DOC" 2>/dev/null; then
      pass "Design doc section: $section"
    else
      fail "Design doc missing section: $section"
      gate_failed=1
    fi
  done

  # Implementation Plan — optional for adopted projects (they're already built)
  if [ "$adopted" = true ]; then
    if grep -q "Implementation Plan" "$DESIGN_DOC" 2>/dev/null; then
      pass "Design doc section: Implementation Plan (optional for adopted)"
    else
      warn "No Implementation Plan — adopted project already exists"
    fi
  else
    if grep -q "Implementation Plan" "$DESIGN_DOC" 2>/dev/null; then
      pass "Design doc section: Implementation Plan"
    else
      fail "Design doc missing section: Implementation Plan"
      gate_failed=1
    fi
  fi

  # ADR directory exists with files
  assert_dir "$ADR_DIR"
  adr_count=$(find "$ADR_DIR" -maxdepth 1 -name 'ADR-*.md' 2>/dev/null | wc -l)
  if [ "$adr_count" -ge 1 ]; then
    pass "$adr_count ADR(s) found"
  elif [ "$adopted" = true ]; then
    warn "No ADRs yet — write retroactive ADRs for key architectural decisions"
  else
    fail "No ADRs found in $ADR_DIR"
    gate_failed=1
  fi

  # ADR index exists
  assert_file "$ADR_DIR/README.md"

  # Design doc approved markers
  if grep -q "Status.*Active" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc status is Active"
  else
    warn "Design doc status not set to Active"
  fi

  # Design reviewed by Reviewers — ensures quality review before implementation
  if [ -f ".design_reviewed" ]; then
    pass "Design reviewed and approved by Reviewers (sequence enforced)"
    queue_cleanup_marker ".design_reviewed"
    record_check "design_reviewed" "PASS"
  else
    fail "Design not reviewed — Reviewers must approve design doc before INIT→ACTIVE"
    gate_failed=1
    record_check "design_reviewed" "FAIL"
  fi

  # Second opinion completed — mandatory cross-model validation before activation
  if [ -f ".second_opinion_done" ]; then
    pass "Second opinion completed (cross-model validation)"
    queue_cleanup_marker ".second_opinion_done"
    record_check "second_opinion_done" "PASS"
  else
    fail "Second opinion not completed — Reviewers must complete cross-model validation before INIT→ACTIVE"
    gate_failed=1
    record_check "second_opinion_done" "FAIL"
  fi

  # User review stop — present design summary and ask for confirmation
  if [ "$gate_failed" -eq 0 ] && ! is_noninteractive; then
    echo ""
    echo "  ─── Design Review ───"
    echo "  Design doc:  $DESIGN_DOC"
    echo "  ADRs:"
    for adr in "$ADR_DIR"/ADR-*.md; do
      title=$(head -1 "$adr" 2>/dev/null | sed 's/^# //')
      echo "    • $(basename "$adr") — $title"
    done
    echo ""
    echo -e "  ${YELLOW}Review the design documents above before proceeding.${NC}"
    echo -n "  Proceed with INIT → ACTIVE? [Y/n] "
    read -r confirm
    case "$confirm" in
      n|N|no|NO) fail "User cancelled — design needs changes" && gate_failed=1 ;;
      *) pass "User approved — proceeding with transition" ;;
    esac
  fi

}

active_to_review() {
  echo ""
  echo "━━━ Gate: ACTIVE → REVIEW ━━━"
  echo ""

  # All features implemented — check TODO (optional for workspaces)
  if [ -f "TODO.md" ]; then
    pass "TODO.md exists"
  else
    warn "No TODO.md — manual completeness check needed"
  fi

  # Tests pass (try tests/run.sh first, then pytest)
  tests_passed=false
  if [ -f "$TEST_RUNNER" ]; then
    if bash "$TEST_RUNNER" 2>&1 | tail -5; then
      pass "All tests pass ($TEST_RUNNER)"
      tests_passed=true
    else
      fail "Test suite has failures — fix before transition"
      gate_failed=1
    fi
  elif [ -d "tests" ] && ls tests/test_*.py &>/dev/null 2>&1; then
    PYTEST_CMD="python3 -m pytest"
    [ -f ".venv/bin/pytest" ] && PYTEST_CMD=".venv/bin/pytest"
    PYTEST_ENV=""
    [ -d "src" ] && PYTEST_ENV="PYTHONPATH=src"
    if env $PYTEST_ENV $PYTEST_CMD tests/ -q 2>&1 | tail -3; then
      pass "All pytest tests pass"
      tests_passed=true
    else
      fail "Pytest suite has failures — fix before transition"
      gate_failed=1
    fi
  else
    fail "No test suite found (tests/run.sh or tests/test_*.py)"
    gate_failed=1
  fi
  if [ "$tests_passed" = true ]; then
    record_check "tests_passing" "PASS"
  else
    record_check "tests_passing" "FAIL"
  fi

  # Testers completed — verify .testers_done marker exists (ensures sequential flow)
  if [ -f ".testers_done" ]; then
    pass "Testers completed before review (sequence enforced)"
    queue_cleanup_marker ".testers_done"
    record_check "testers_done" "PASS"
  else
    fail "Testers did not complete before review — must run Testers before Reviewers"
    gate_failed=1
    record_check "testers_done" "FAIL"
  fi

  # Code reviewed — verify .code_reviewed marker exists (Reviewers must approve before ACTIVE→REVIEW)
  if [ -f ".code_reviewed" ]; then
    pass "Code reviewed and approved by Reviewers"
    queue_cleanup_marker ".code_reviewed"
    record_check "code_reviewed" "PASS"
  else
    fail "Code not reviewed — Reviewers must approve implementation before ACTIVE→REVIEW"
    gate_failed=1
    record_check "code_reviewed" "FAIL"
  fi

  # Code reviewed — check for recent review commits
  if git log --oneline -20 2>/dev/null | grep -qiE "review|reviewed|approve"; then
    pass "Recent review commits found"
  else
    warn "No review commits in recent history — manual check needed"
  fi
}

review_to_closed() {
  echo ""
  echo "━━━ Gate: REVIEW → CLOSED ━━━"
  echo ""

  # Test suite green (try tests/run.sh first, then pytest)
  tests_passed=false
  if [ -f "$TEST_RUNNER" ]; then
    if bash "$TEST_RUNNER" 2>&1 | tail -5; then
      pass "All tests pass ($TEST_RUNNER)"
      tests_passed=true
    else
      fail "Test suite has failures"
      gate_failed=1
    fi
  elif [ -d "tests" ] && ls tests/test_*.py &>/dev/null 2>&1; then
    PYTEST_CMD="python3 -m pytest"
    [ -f ".venv/bin/pytest" ] && PYTEST_CMD=".venv/bin/pytest"
    PYTEST_ENV=""
    [ -d "src" ] && PYTEST_ENV="PYTHONPATH=src"
    if env $PYTEST_ENV $PYTEST_CMD tests/ -q 2>&1 | tail -3; then
      pass "All pytest tests pass"
      tests_passed=true
    else
      fail "Pytest suite has failures"
      gate_failed=1
    fi
  else
    fail "No test suite found (tests/run.sh or tests/test_*.py)"
    gate_failed=1
  fi
  if [ "$tests_passed" = true ]; then
    record_check "tests_passing" "PASS"
  else
    record_check "tests_passing" "FAIL"
  fi

  # Design doc matches implementation (structural consistency)
  assert_file "$DESIGN_DOC"
  if [ -f "$DESIGN_DOC" ]; then
    record_check "design_doc_exists" "PASS"
  else
    record_check "design_doc_exists" "FAIL"
  fi

  # Agentmemory accessible (health check)
  if command -v curl &>/dev/null; then
      && pass "Agentmemory daemon accessible" \
      || warn "Agentmemory daemon not reachable at localhost:3111"
  else
