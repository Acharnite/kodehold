#!/usr/bin/env bash
# KodeHold Lifecycle Gate — run automated quality checks before state transitions
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }

STATE_FILE=".kodehold-state"
DESIGN_DOC="docs/design/README.md"
ADR_DIR="docs/adr"
TEST_RUNNER="tests/run.sh"
ICM_DB=".icm/memories.db"

gate_failed=0
check() {
  if ! "$@" >/dev/null 2>&1; then
    fail "$1 failed"
    gate_failed=1
  fi
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

  # Design doc exists and has all 11 sections
  assert_file "$DESIGN_DOC"
  for section in "Purpose & Scope" "Requirements" "Architecture Overview" "Component Design" "Data Model" "API Design" "Implementation Plan" "Testing Strategy" "ADR Index" "Open Questions" "Changelog"; do
    if grep -q "$section" "$DESIGN_DOC" 2>/dev/null; then
      pass "Design doc section: $section"
    else
      fail "Design doc missing section: $section"
      gate_failed=1
    fi
  done

  # ADR directory exists with files
  assert_dir "$ADR_DIR"
  adr_count=$(ls "$ADR_DIR"/ADR-*.md 2>/dev/null | wc -l)
  if [ "$adr_count" -ge 1 ]; then
    pass "$adr_count ADR(s) found"
  else
    fail "No ADRs found in $ADR_DIR"
    gate_failed=1
  fi

  # ADR index exists
  assert_file "$ADR_DIR/README.md"

  # Design doc approved markers
  if grep -q "Status: Active" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc status is Active"
  else
    warn "Design doc status not set to Active"
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
  if [ -f "$TEST_RUNNER" ]; then
    if bash "$TEST_RUNNER" 2>&1 | tail -5; then
      pass "All tests pass ($TEST_RUNNER)"
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
    else
      fail "Pytest suite has failures — fix before transition"
      gate_failed=1
    fi
  else
    fail "No test suite found (tests/run.sh or tests/test_*.py)"
    gate_failed=1
  fi

  # Testers completed — verify .testers_done marker exists (ensures sequential flow)
  if [ -f ".testers_done" ]; then
    pass "Testers completed before review (sequence enforced)"
    rm -f ".testers_done"
  else
    fail "Testers did not complete before review — must run Testers before Reviewers"
    gate_failed=1
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
  if [ -f "$TEST_RUNNER" ]; then
    if bash "$TEST_RUNNER" 2>&1 | tail -5; then
      pass "All tests pass ($TEST_RUNNER)"
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
    else
      fail "Pytest suite has failures"
      gate_failed=1
    fi
  else
    fail "No test suite found (tests/run.sh or tests/test_*.py)"
    gate_failed=1
  fi

  # Design doc matches implementation (structural consistency)
  assert_file "$DESIGN_DOC"

  # ICM database exists and is accessible (check if .icm/ exists — optional for workspaces)
  if [ -d ".icm" ]; then
    if [ -f "$ICM_DB" ]; then
      pass "ICM database exists"
      command -v icm &>/dev/null && icm stats --db "$ICM_DB" &>/dev/null && pass "ICM database accessible" || warn "ICM stats check failed"
    else
      warn "ICM directory present but no database at $ICM_DB — run icm init"
    fi
  else
    warn "No .icm/ directory — using central KodeHold ICM for memory"
  fi

  # Git is clean (no uncommitted changes)
  if git diff --quiet 2>/dev/null; then
    pass "Working tree clean"
  else
    warn "Uncommitted changes exist — should commit before CLOSED"
  fi
}

closed_to_reopen() {
  echo ""
  echo "━━━ Gate: CLOSED → REOPEN ━━━"
  echo ""

  # Design doc exists and has been updated
  assert_file "$DESIGN_DOC"
  if grep -q "Last Updated:" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc has update timestamp"
  fi

  # Impact analysis — check docs/decisions or recent notes
  if [ -d "docs/decisions" ] && ls docs/decisions/*.md &>/dev/null 2>&1; then
    pass "Impact analysis notes found"
  else
    warn "No impact analysis in docs/decisions/ — manual check needed"
  fi
}

reopen_to_active() {
  echo ""
  echo "━━━ Gate: REOPEN → ACTIVE ━━━"
  echo ""

  # Design doc approved
  assert_file "$DESIGN_DOC"
  if grep -q "Status: Active" "$DESIGN_DOC" 2>/dev/null; then
    pass "Design doc status is Active"
  else
    warn "Design doc status not set to Active"
  fi

  # New ADRs if needed
  assert_dir "$ADR_DIR"
}

usage() {
  echo "Usage: $0 --transition <FROM>_TO_<TO>"
  echo ""
  echo "Transitions:"
  echo "  INIT_TO_ACTIVE    — design doc complete, ADRs written"
  echo "  ACTIVE_TO_REVIEW  — features implemented, tests pass, code reviewed"
  echo "  REVIEW_TO_CLOSED  — final sign-off, tests green, ICM stored"
  echo "  CLOSED_TO_REOPEN  — impact analysis, design doc updated"
  echo "  REOPEN_TO_ACTIVE  — design doc approved, new ADRs"
  echo ""
  echo "Options:"
  echo "  --transition  The state transition to validate"
  echo "  --list        List all gates and their checks"
  echo "  --status      Show current lifecycle state"
  echo ""
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

case "${1:-}" in
  --transition)
    shift
    transition="${1:-}"
    case "$transition" in
      INIT_TO_ACTIVE)    init_to_active ;;
      ACTIVE_TO_REVIEW)  active_to_review ;;
      REVIEW_TO_CLOSED)  review_to_closed ;;
      CLOSED_TO_REOPEN)  closed_to_reopen ;;
      REOPEN_TO_ACTIVE)  reopen_to_active ;;
      *)                 echo "Unknown transition: $transition"; usage ;;
    esac
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
    if [ -f "$STATE_FILE" ]; then
      cat "$STATE_FILE"
    else
      echo "No state file found — project not initialized"
    fi
    exit 0
    ;;
  *)
    usage
    ;;
esac

echo ""
if [ "$gate_failed" -eq 0 ]; then
  echo -e "  ${GREEN}━━━ GATE PASSED ━━━${NC}"
else
  echo -e "  ${RED}━━━ GATE BLOCKED — fix failures above ━━━${NC}"
fi
echo ""

exit "$gate_failed"
