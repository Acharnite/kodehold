#!/usr/bin/env bash
# KodeHold Lifecycle Gate — run automated quality checks before state transitions
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
info() { echo -e "  ${CYAN}i${NC} $1"; }

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

  # ICM accessible (central KodeHold database)
  if command -v icm &>/dev/null; then
    icm stats &>/dev/null && pass "ICM accessible (central database)" || warn "ICM stats check failed"
  else
    warn "ICM not installed — skip ICM check"
  fi

  # Git is clean (no uncommitted changes)
  if git diff --quiet 2>/dev/null; then
    pass "Working tree clean"
  else
    warn "Uncommitted changes exist — should commit before CLOSED"
  fi

  # Clean up lifecycle markers — fresh state for next reopen
  queue_cleanup_marker ".design_reviewed"
  queue_cleanup_marker ".testers_done"
  queue_cleanup_marker ".impact_analysis_done"
  queue_cleanup_marker ".code_reviewed"
  queue_cleanup_marker ".second_opinion_done"
  queue_cleanup_marker ".team_meeting_done"

  # User review stop — ask for confirmation before closing
  if [ "$gate_failed" -eq 0 ] && ! is_noninteractive; then
    echo ""
    echo -e "  ${YELLOW}Proceed with REVIEW → CLOSED? (y/N)${NC} "
    read -r confirm
    case "$confirm" in
      y|Y|yes|YES) pass "User approved — proceeding with transition" ;;
      *) fail "User cancelled — REVIEW → CLOSED aborted" && gate_failed=1 ;;
    esac
  fi
}

closed_to_reopen() {
  echo ""
  echo "━━━ Gate: CLOSED → REOPEN ━━━"
  echo ""

  # Design doc exists and has been updated
  assert_file "$DESIGN_DOC"
  if [ -f "$DESIGN_DOC" ]; then
    record_check "design_doc_exists" "PASS"
  else
    record_check "design_doc_exists" "FAIL"
  fi
  if grep -q "Last Updated:" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc has update timestamp"
  fi

  # Impact analysis — check docs/decisions or recent notes
  if [ -d "docs/decisions" ] && ls docs/decisions/*.md &>/dev/null 2>&1; then
    pass "Impact analysis notes found"
  else
    warn "No impact analysis in docs/decisions/ — manual check needed"
  fi

  # Impact analysis completed by Architects — ensures quality assessment before reopening
  if [ -f ".impact_analysis_done" ]; then
    pass "Impact analysis completed by Architects (sequence enforced)"
    queue_cleanup_marker ".impact_analysis_done"
    record_check "impact_analysis_done" "PASS"
  else
    fail "Impact analysis not completed — Architects must assess scope before CLOSED→REOPEN"
    gate_failed=1
    record_check "impact_analysis_done" "FAIL"
  fi
}

reopen_to_active() {
  echo ""
  echo "━━━ Gate: REOPEN → ACTIVE ━━━"
  echo ""

  # Design doc approved
  assert_file "$DESIGN_DOC"
  if [ -f "$DESIGN_DOC" ]; then
    record_check "design_doc_exists" "PASS"
  else
    record_check "design_doc_exists" "FAIL"
  fi
  if grep -q "Status.*Active" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc status is Active"
  else
    warn "Design doc status not set to Active"
  fi

  # New ADRs if needed
  assert_dir "$ADR_DIR"
  if [ -d "$ADR_DIR" ]; then
    record_check "adr_dir_exists" "PASS"
  else
    record_check "adr_dir_exists" "FAIL"
  fi

  # Second opinion completed — mandatory before REOPEN→ACTIVE
  if [ -f ".second_opinion_done" ]; then
    pass "Second opinion completed for updated design"
    queue_cleanup_marker ".second_opinion_done"
    record_check "second_opinion_done" "PASS"
  else
    fail "Second opinion not completed — Reviewers must complete cross-model validation before REOPEN→ACTIVE"
    gate_failed=1
    record_check "second_opinion_done" "FAIL"
  fi
}

usage() {
  echo "Usage: $0 --transition <FROM>_TO_<TO> [OPTIONS]"
  echo ""
  echo "Transitions:"
  echo "  INIT_TO_ACTIVE    — design doc complete, ADRs written"
  echo "  ACTIVE_TO_REVIEW  — features implemented, tests pass, code reviewed"
  echo "  REVIEW_TO_CLOSED  — final sign-off, tests green, ICM stored"
  echo "  CLOSED_TO_REOPEN  — impact analysis, design doc updated"
  echo "  REOPEN_TO_ACTIVE  — design doc approved, new ADRs"
  echo ""
  echo "Options:"
  echo "  --transition     The state transition to validate"
  echo "  --project-path   Path to project directory (default: current dir)"
  echo "  --validate-only  Run checks without executing transition (for Reviewers)"
  echo "  --reviewer-mode  Output structured results for Reviewers (PASS/BLOCKED per check)"
  echo "  --list           List all gates and their checks"
  echo "  --status         Show current lifecycle state"
  echo "  --yes            Skip interactive prompts (for CI/automation)"
  echo ""
  echo "Environment:"
  echo "  OPENCODE_NONINTERACTIVE=true  Skip all interactive prompts"
  echo ""
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

# Parse flags — supports --transition with optional --validate-only and --reviewer-mode
# Also supports shorthand: --validate-only ACTIVE_TO_REVIEW (without --transition)
transition=""
while [ $# -gt 0 ]; do
  case "$1" in
    --transition)
      shift
      transition="${1:-}"
      ;;
    --validate-only)
      validate_only=true
      # If next arg is not a flag, treat it as the transition (shorthand syntax)
      if [ $# -gt 1 ] && [[ ! "${2:-}" =~ ^-- ]]; then
        shift
        transition="${1:-}"
      fi
      ;;
    --reviewer-mode)
      reviewer_mode=true
      # If next arg is not a flag, treat it as the transition (shorthand syntax)
      if [ $# -gt 1 ] && [[ ! "${2:-}" =~ ^-- ]]; then
        shift
        transition="${1:-}"
      fi
      ;;
    --project-path)
      shift
      PROJECT_PATH="${1:-}"
      ;;
    --list)
      echo "Available transitions:"
      echo "  INIT_TO_ACTIVE"
      echo "  ACTIVE_TO_REVIEW"
      echo "  REVIEW_TO_CLOSED"
      echo "  CLOSED_TO_REOPEN"
      echo "  REOPEN_TO_ACTIVE"
      exit 0
      ;;
    --status)
      show_status=true
      ;;
    --yes)
      OPENCODE_NONINTERACTIVE=true bash "$0" "${@:2}"
      exit $?
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
  shift
done

# Change to project path if specified (so all relative paths resolve correctly)
if [ -n "$PROJECT_PATH" ]; then
  if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path not found: $PROJECT_PATH"
    echo "Usage: $0 --project-path <path> [--transition <transition>]"
    echo "Example: $0 --project-path workspaces/my-project --status"
    exit 1
  fi
  cd "$(realpath "$PROJECT_PATH" 2>/dev/null || echo "$PROJECT_PATH")"
fi

# Handle --status (deferred so --project-path is processed first)
if [ "$show_status" = true ]; then
  if [ -f "$STATE_FILE" ]; then
    cat "$STATE_FILE"
  else
    echo "No state file found — project not initialized"
  fi
  exit 0
fi

if [ -z "$transition" ]; then
  echo "Error: --transition is required"
  usage
fi

case "$transition" in
  INIT_TO_ACTIVE)    init_to_active ;;
  ACTIVE_TO_REVIEW)  active_to_review ;;
  REVIEW_TO_CLOSED)  review_to_closed ;;
  CLOSED_TO_REOPEN)  closed_to_reopen ;;
  REOPEN_TO_ACTIVE)  reopen_to_active ;;
  *)                 echo "Unknown transition: $transition"; usage ;;
esac

echo ""
if [ "$gate_failed" -eq 0 ]; then
  if [ "$validate_only" = true ]; then
    echo -e "  ${GREEN}━━━ VALIDATION PASSED — transition is allowed ━━━${NC}"
  else
    echo -e "  ${GREEN}━━━ GATE PASSED ━━━${NC}"
  fi
else
  if [ "$validate_only" = true ]; then
    echo -e "  ${RED}━━━ VALIDATION BLOCKED — transition not allowed ━━━${NC}"
  else
    echo -e "  ${RED}━━━ GATE BLOCKED — fix failures above ━━━${NC}"
  fi
fi
echo ""

# Reviewer mode: output structured results
if [ "$reviewer_mode" = true ]; then
  echo "─── Reviewer Mode Output ───"
  if [ "$gate_failed" -eq 0 ]; then
    echo "GATE_RESULT:PASS"
  else
    echo "GATE_RESULT:BLOCKED"
  fi
  echo "TRANSITION:$transition"
  echo "VALIDATE_ONLY:$validate_only"
  # Build CHECKS line
  checks_line=""
  for key in "${!check_results[@]}"; do
    if [ -n "$checks_line" ]; then
      checks_line+=","
    fi
    checks_line+="${key}:${check_results[$key]}"
  done
  echo "CHECKS:$checks_line"
  # Determine MARKERS_REQUIRED based on transition
  markers_required=""
  case "$transition" in
    INIT_TO_ACTIVE) markers_required=".design_reviewed .second_opinion_done" ;;
    ACTIVE_TO_REVIEW) markers_required=".code_reviewed .testers_done" ;;
    REVIEW_TO_CLOSED) markers_required="" ;;
    CLOSED_TO_REOPEN) markers_required="" ;;
    REOPEN_TO_ACTIVE) markers_required=".second_opinion_done" ;;
  esac
  echo "MARKERS_REQUIRED:$markers_required"
  if [ "${#cleanup_markers[@]}" -gt 0 ]; then
    echo "MARKERS_CLEANUP:${cleanup_markers[*]}"
  fi
  echo "────────────────────────────"
fi

# In validate-only mode, do NOT clean markers or modify state
if [ "$validate_only" = false ] && [ "$gate_failed" -eq 0 ]; then
  cleanup_markers_on_pass

  # Trigger memoir distillation for Scribes (ADR-0009 phase 4)
  # After CLOSED transition, Scribes should distill project memories into memoirs
  if [ "$transition" = "REVIEW_TO_CLOSED" ]; then
    touch .distill_needed
    pass "Memoir distillation marker created (.distill_needed)"
  fi
fi

exit "$gate_failed"
