#!/usr/bin/env bash
# KodeHold Shipping Gate — automated steps 1-7 of 8-step shipping process
# Step 0 (Team Meeting) must be completed manually before running this script
#
# Usage:
#   bash scripts/ship.sh                  # Run shipping gate checks
#   bash scripts/ship.sh --generate-changes  # Auto-generate CHANGES.md entry from git log
#
# --generate-changes
#   Reads commits since the last tag, groups them by conventional commit type,
#   and inserts a new version entry at the top of CHANGES.md. This is a
#   convenience feature — you can still write entries manually.
set -euo pipefail
JSON_MODE="${JSON_MODE:-false}"
SHIP_FAILED=0

source "$(dirname "$0")/lib/output.sh"
fail() {
  if [ "${JSON_MODE:-false}" = true ]; then
    SHIP_FAILED=1
    json_add "ship_check" "FAIL" "$1"
  else
    echo -e "  ${RED}✗${NC} $1"
    exit 1
  fi
}

# ── --generate-changes ──────────────────────────────────────────────────────

generate_changes() {
  # Determine version from VERSION.md
  local ver
  ver=$(grep -oP '(?<=^\| )\s*\d+\.\d+\.\d+\s*(?= \|)' VERSION.md | head -1 | xargs)
  [ -z "$ver" ] && fail "Could not parse version from VERSION.md"

  local today
  today=$(date -u '+%Y-%m-%d')

  # Check if entry already exists
  if grep -q "^## $ver " CHANGES.md 2>/dev/null; then
    warn "CHANGES.md already has an entry for v$ver — skipping generation"
    return 0
  fi

  # Get commits since last tag
  local last_tag
  last_tag=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || echo "")

  local raw_log
  if [ -n "$last_tag" ]; then
    raw_log=$(git log --oneline "${last_tag}..HEAD" 2>/dev/null)
  else
    raw_log=$(git log --oneline 2>/dev/null)
  fi
  if [ -z "$raw_log" ]; then
    warn "No commits found since last tag — nothing to generate"
    return 0
  fi

  # Classify commits by conventional commit type
  local added="" changed="" fixed="" docs="" ci="" other=""
  while IFS= read -r line; do
    # Extract subject after the short hash
    local subject="${line#* }"
    # Strip scope prefix like "feat(scope): " → keep description
    local desc
    desc=$(echo "$subject" | sed -E 's/^[a-z]+(\([^)]*\))?[ :] *//')
    # Capitalise first letter
    desc="$(echo "${desc:0:1}" | tr '[:lower:]' '[:upper:]')${desc:1}"

    case "$subject" in
      feat*|add*)          added="$added\n- $desc" ;;
      fix*|bug*)          fixed="$fixed\n- $desc" ;;
      docs*|doc*)         docs="$docs\n- $desc" ;;
      refactor*)          changed="$changed\n- $desc" ;;
      ci*|chore*)         ci="$ci\n- $desc" ;;
      test*)              ;;  # skip internal test commits
      *)                  other="$other\n- $desc" ;;
    esac
  done <<< "$raw_log"

  # Build the new entry
  local entry="## $ver — $today"
  [ -n "$added" ]   && entry="$entry\n\n### Added$added"
  [ -n "$changed" ] && entry="$entry\n\n### Changed$changed"
  [ -n "$fixed" ]   && entry="$entry\n\n### Fixed$fixed"
  [ -n "$docs" ]    && entry="$entry\n\n### Docs$docs"
  [ -n "$ci" ]      && entry="$entry\n\n### CI$ci"
  [ -n "$other" ]   && entry="$entry\n\n### Other$other"

  # Insert after "# Changelog" header
  local tmp
  tmp=$(mktemp)
  # Find line number of first version entry (first "## " after header)
  local start_line
  start_line=$(grep -n '^## ' CHANGES.md | head -1 | cut -d: -f1)
  {
    echo "# Changelog"
    echo ""
    echo -e "$entry"
    echo ""
    # Append everything from the first existing version entry onwards
    if [ -n "$start_line" ]; then
      tail -n "+$start_line" CHANGES.md
    fi
  } > "$tmp"
  mv "$tmp" CHANGES.md
  pass "Generated CHANGES.md entry for v$ver ($today)"
  echo ""
  echo "Generated entry:"
  echo "────────────────"
  echo -e "$entry"
  echo "────────────────"
  echo ""
  echo "Review and edit CHANGES.md before shipping."
}

# ── Parse arguments ─────────────────────────────────────────────────────────

GENERATE=false
for arg in "$@"; do
  case "$arg" in
    --generate-changes) GENERATE=true ;;
    --json) JSON_MODE=true ;;
  esac
done

if [ "$GENERATE" = true ]; then
  echo ""
  echo "=========================================="
  echo "  Generating CHANGES.md entry"
  echo "=========================================="
  echo ""
  generate_changes
  exit 0
fi

# ── Self-modification check ───────────────────────────────────────────────
# If KodeHold is modifying itself, skip the shipping gate to avoid circular
# self-gating. Detection is based on env var, marker file, or git diff.
if is_self_modification; then
  echo ""
  if [ "$JSON_MODE" = true ]; then
    json_add "self_modification" "PASS" "KodeHold self-modification detected — ship gate skipped"
    json_emit "ship.sh" "PASS" ""
    exit 0
  fi
  echo -e "  ${YELLOW}━━━ KodeHold self-modification detected — skipping shipping gate ━━━${NC}"
  echo ""
  exit 0
fi

[ "${JSON_MODE:-false}" = true ] || echo ""
[ "${JSON_MODE:-false}" = true ] || echo "=========================================="
[ "${JSON_MODE:-false}" = true ] || echo "  KodeHold Shipping Gate"
[ "${JSON_MODE:-false}" = true ] || echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
[ "${JSON_MODE:-false}" = true ] || echo "=========================================="
[ "${JSON_MODE:-false}" = true ] || echo ""

# 1. Version check
if [ ! -f VERSION.md ]; then
  fail "VERSION.md not found"
fi
current_ver=$(grep -oP '(?<=^\| )\s*\d+\.\d+\.\d+\s*(?= \|)' VERSION.md | head -1 | xargs)
if [ -n "$current_ver" ]; then
  json_add "version_file" "PASS" "$current_ver"
  pass "Current version: $current_ver"
else
  json_add "version_file" "FAIL"
  fail "Could not parse version from VERSION.md"
fi
[ "${JSON_MODE:-false}" = true ] || echo ""

# 2. CHANGES.md check
if [ ! -f CHANGES.md ]; then
  fail "CHANGES.md not found"
fi
if grep -q "^## $current_ver " CHANGES.md 2>/dev/null; then
  json_add "changelog" "PASS"
  pass "CHANGES.md entry found for v$current_ver"
else
  json_add "changelog" "FAIL" "No entry for v$current_ver"
  fail "No entry for v$current_ver in CHANGES.md — add one before shipping"
fi
[ "${JSON_MODE:-false}" = true ] || echo ""

# 3. TODO.md check
if [ -f TODO.md ]; then
  json_add "todo_file" "PASS"
  pass "TODO.md exists"
else
  json_add "todo_file" "FAIL"
  fail "TODO.md not found"
fi
[ "$JSON_MODE" = true ] || echo ""

# 4. Test suite
if [ "${JSON_MODE:-false}" = true ]; then
  if [ -f tests/run.sh ]; then
    if bash tests/run.sh 2>/dev/null >/dev/null; then
      json_add "tests" "PASS"
      pass "All tests pass"
    else
      json_add "tests" "FAIL"
      fail "Test suite failed — fix before shipping"
    fi
  else
    json_add "tests" "FAIL" "tests/run.sh not found"
    fail "tests/run.sh not found"
  fi
else
  if [ -f tests/run.sh ]; then
    if bash tests/run.sh; then
      pass "All tests pass"
    else
      fail "Test suite failed — fix before shipping"
    fi
  else
    fail "tests/run.sh not found"
  fi
fi
[ "$JSON_MODE" = true ] || echo ""

# 5. Git status
if git diff --stat --cached | grep -q .; then
  json_add "git_status" "PASS" "staged"
  pass "Changes staged for commit"
elif git diff --stat | grep -q .; then
  json_add "git_status" "WARN" "unstaged changes"
  warn "Unstaged changes exist — stage them before committing"
else
  if git ls-files --others --exclude-standard | grep -q .; then
    json_add "git_status" "WARN" "untracked files"
    warn "Untracked files exist — check git status"
  else
    json_add "git_status" "PASS" "clean"
  fi
fi
echo ""

# 6. PR check
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]; then
  json_add "branch" "PASS" "main"
  pass "On main branch — direct push"
else
  json_add "branch" "WARN" "$branch"
  warn "On branch '$branch' — remember to create PR: gh pr create"
fi
[ "$JSON_MODE" = true ] || echo ""

if [ "$JSON_MODE" = true ]; then
  if [ "$SHIP_FAILED" -eq 1 ]; then
    json_emit "ship.sh" "FAIL" "$current_ver"
    exit 1
  fi
  json_emit "ship.sh" "PASS" "$current_ver"
  exit 0
else
  echo "=========================================="
  echo -e "  ${GREEN}Pre-ship Checks Passed (6/6)${NC}"
  echo "=========================================="
  echo ""
  echo "  Director: you must now manually execute:"
  echo "    1. Bump VERSION.md (MAJOR/MINOR/PATCH)"
  echo "    2. Update CHANGES.md with version + date + changes"
  echo "    3. Store release: Store release note in .opencode/memory/releases/"
  echo "    4. Delegate structured commit to Scribes"
  echo "    5. Push: git push"
  echo "    6. Tag: git tag v<ver> && git push origin v<ver>"
  echo ""
  echo "  See director.md § Shipping Gate for full protocol."
  echo ""
  exit 0
fi
