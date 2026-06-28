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

source "$(dirname "$0")/lib/output.sh"
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

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

echo ""
echo "=========================================="
echo "  KodeHold Shipping Gate"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=========================================="
echo ""

# 1. Version check
if [ ! -f VERSION.md ]; then
  fail "VERSION.md not found"
fi
current_ver=$(grep -oP '(?<=^\| )\s*\d+\.\d+\.\d+\s*(?= \|)' VERSION.md | head -1 | xargs)
[ -n "$current_ver" ] && pass "Current version: $current_ver" || fail "Could not parse version from VERSION.md"
echo ""

# 2. CHANGES.md check
if [ ! -f CHANGES.md ]; then
  fail "CHANGES.md not found"
fi
grep -q "^## $current_ver " CHANGES.md 2>/dev/null || fail "No entry for v$current_ver in CHANGES.md — add one before shipping"
echo ""

# 3. TODO.md check
[ -f TODO.md ] && pass "TODO.md exists" || fail "TODO.md not found"
echo ""

# 4. Test suite
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

# 5. Agentmemory store check
if command -v curl &>/dev/null; then
    && pass "Agentmemory daemon accessible" \
    || warn "Agentmemory daemon not reachable — memories may not be stored"
else
fi
echo ""

# 6. Git status
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
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]; then
  pass "On main branch — direct push"
else
  warn "On branch '$branch' — remember to create PR: gh pr create"
fi
echo ""

echo "=========================================="
echo -e "  ${GREEN}Pre-ship Checks Passed (7/7)${NC}"
echo "=========================================="
echo ""
echo "  Director: you must now manually execute:"
echo "    1. Bump VERSION.md (MAJOR/MINOR/PATCH)"
echo "    2. Update CHANGES.md with version + date + changes"
echo "    3. Store release: Store release note in .opencode/memory/releases/
echo "    4. Delegate structured commit to Scribes"
echo "    5. Push: git push"
echo "    6. Tag: git tag v<ver> && git push origin v<ver>"
echo ""
echo "  See director.md § Shipping Gate for full protocol."
echo ""
