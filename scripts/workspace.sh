#!/usr/bin/env bash
# KodeHold Workspace Manager — create, list, and manage project workspaces
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }
info() { echo -e "  ${CYAN}i${NC} $1"; }

WORKSPACE_ROOT="workspaces"
CATALOG="$WORKSPACE_ROOT/.catalog"
GATE_SCRIPT="scripts/gate.sh"

ensure_catalog() {
  if [ ! -f "$CATALOG" ]; then
    echo '{}' > "$CATALOG"
  fi
}

catalog_read() {
  ensure_catalog
  cat "$CATALOG"
}

catalog_write() {
  echo "$1" > "$CATALOG"
}

ws_init() {
  local name="$1"
  local ws_dir="$WORKSPACE_ROOT/$name"

  if [ -d "$ws_dir" ]; then
    fail "Workspace '$name' already exists at $ws_dir"
  fi

  info "Creating workspace: $name"
  mkdir -p "$ws_dir"/{docs/design,docs/adr,docs/decisions,src,tests}

  # Design doc template
  cat > "$ws_dir/docs/design/README.md" << EOF
# $name — Design Document
**Version:** 0.1
**Status:** Draft
**Design Authority:** Architects
**Last Reviewed:** $(date +%Y-%m-%d)

## 1. Purpose & Scope
## 2. Requirements
## 3. Architecture Overview
## 4. Component Design
## 5. Data Model
## 6. API Design
## 7. Implementation Plan
## 8. Testing Strategy
## 9. ADR Index
## 10. Open Questions
## 11. Changelog
EOF

  # ADR template directory
  cat > "$ws_dir/docs/adr/README.md" << EOF
# ADR Index — $name

| ADR | Title | Status |
|-----|-------|--------|
EOF

  # State file
  cat > "$ws_dir/.kodehold-state" << EOF
# KodeHold Lifecycle State
# Valid states: INIT, ACTIVE, REVIEW, CLOSED, REOPEN
STATE=INIT
LAST_UPDATED=$(date +%Y-%m-%d)
DESIGN_DOC_APPROVED=false
ADRS_COMPLETE=false
TESTS_PASSING=false
CODE_REVIEWED=false
EOF

  # .gitignore inside workspace
  echo "*.pyc
__pycache__/
.venv/" > "$ws_dir/.gitignore"

  # Register in catalog
  local catalog
  catalog=$(catalog_read)
  catalog=$(echo "$catalog" | jq \
    --arg n "$name" \
    --arg p "$ws_dir" \
    '. + {($n): {"state": "INIT", "created": now | strftime("%Y-%m-%d"), "path": $p}}')
  catalog_write "$catalog"

  pass "Workspace '$name' created at $ws_dir"
}

ws_adopt() {
  local name="$1"
  local target_path="$2"
  local ws_dir="$WORKSPACE_ROOT/$name"

  if [ -z "$name" ] || [ -z "$target_path" ]; then
    fail "Usage: bash scripts/workspace.sh adopt <name> <path-to-existing-project>"
  fi

  if [ -e "$ws_dir" ]; then
    fail "Workspace '$name' already exists at $ws_dir"
  fi

  if [ ! -d "$target_path" ]; then
    fail "Target path does not exist: $target_path"
  fi

  # Resolve to absolute path
  target_path="$(cd "$target_path" && pwd 2>/dev/null)" || fail "Cannot resolve path: $target_path"

  info "Adopting existing project: $target_path → $ws_dir"
  ln -s "$target_path" "$ws_dir"

  # Create KodeHold artifacts inside the adopted project
  mkdir -p "$ws_dir/docs/design" "$ws_dir/docs/adr" "$ws_dir/.icm"
  touch "$ws_dir/.icm/config.toml"

  # .kodehold-state with ADOPTED flag
  cat > "$ws_dir/.kodehold-state" << EOF
# KodeHold Lifecycle State — Adopted Project
# Valid states: INIT, ACTIVE, REVIEW, CLOSED, REOPEN
STATE=INIT
ADOPTED=true
LAST_UPDATED=$(date +%Y-%m-%d)
DESIGN_DOC_APPROVED=false
ADRS_COMPLETE=false
TESTS_PASSING=false
CODE_REVIEWED=false
EOF

  # .gitignore addition for .icm/ if not present
  local gitignore="$ws_dir/.gitignore"
  if [ -f "$gitignore" ]; then
    if ! grep -q "^\.icm/" "$gitignore" 2>/dev/null; then
      echo -e "\n# KodeHold\n.icm/" >> "$gitignore"
    fi
  else
    echo "# KodeHold" > "$gitignore"
    echo ".icm/" >> "$gitignore"
  fi

  # Quick project scan for design doc
  local lang=""
  local test_framework=""
  local build_system=""
  if [ -f "$ws_dir/package.json" ]; then
    lang="JavaScript/TypeScript"
    test_framework=$(grep -oP '"(jest|vitest|mocha|playwright)"' "$ws_dir/package.json" 2>/dev/null | head -1 | tr -d '"' || echo "")
    build_system=$(grep -oP '"build":\s*"[^"]+"' "$ws_dir/package.json" 2>/dev/null | head -1 || echo "")
  elif [ -f "$ws_dir/Cargo.toml" ]; then
    lang="Rust"
    test_framework="cargo test (built-in)"
    build_system="cargo"
  elif [ -f "$ws_dir/pyproject.toml" ]; then
    lang="Python"
    test_framework=$(grep -oP '(pytest|unittest)' "$ws_dir/pyproject.toml" 2>/dev/null | head -1 || echo "pytest")
    build_system="pip/setuptools"
  elif [ -f "$ws_dir/go.mod" ]; then
    lang="Go"
    test_framework="go test (built-in)"
    build_system="go build"
  elif [ -f "$ws_dir/Makefile" ]; then
    lang="Unknown (has Makefile)"
    build_system="make"
  else
    lang="Unknown"
    build_system="Unknown"
  fi

  local file_count
  file_count=$(find "$ws_dir" -not -path '*/.git/*' -not -path '*/.icm/*' -not -name '.gitignore' -not -name '.kodehold-state' -type f 2>/dev/null | wc -l)
  local commit_count=0
  if [ -d "$ws_dir/.git" ]; then
    commit_count=$(git -C "$ws_dir" log --oneline 2>/dev/null | wc -l)
  fi

  # Design doc template
  cat > "$ws_dir/docs/design/README.md" << EOF
# $name — Design Document
**Version:** 0.1
**Status:** Draft
**Design Authority:** Architects
**Last Reviewed:** $(date +%Y-%m-%d)
**Origin:** Adopted ($target_path)

> Project adopted by KodeHold on $(date +%Y-%m-%d). It was not originally created with KodeHold.
> This design document is a retroactive description of the existing codebase.

## 1. Purpose & Scope
_Describe what this project does — derived from existing code._

## 2. Requirements
_Reverse-engineered from existing functionality._

## 3. Architecture Overview
_Describe the existing architecture._

- Language: $lang
- Build system: $build_system
- Test framework: ${test_framework:-None detected}
- $file_count source files, $commit_count git commits

## 4. Component Design
_Catalogue existing components and modules._

## 5. Data Model
_Document existing data structures and schemas._

## 6. API Design
_Document existing API endpoints and interfaces._

## 7. Implementation Plan
_No forward plan — this project is already implemented. Use for feature additions._

## 8. Testing Strategy
_Describe existing test approach._

- Test framework: ${test_framework:-Not detected}
- _Add test discovery results here_

## 9. ADR Index
_Record architectural decisions retroactively as ADRs._

## 10. Open Questions
_What needs to be understood about the codebase._

## 11. Changelog
- $(date +%Y-%m-%d): Adopted by KodeHold — design doc created retroactively
EOF

  # ADR index
  cat > "$ws_dir/docs/adr/README.md" << EOF
# ADR Index — $name (Adopted Project)

| ADR | Title | Status |
|-----|-------|--------|
EOF

  info "Project scan complete: $lang, $file_count files, $commit_count commits"

  # Register in catalog
  local catalog
  catalog=$(catalog_read)
  catalog=$(echo "$catalog" | jq \
    --arg n "$name" \
    --arg p "$ws_dir" \
    --arg r "$target_path" \
    '. + {($n): {"state": "INIT", "created": now | strftime("%Y-%m-%d"), "path": $p, "origin": "adopted", "real_path": $r}}')
  catalog_write "$catalog"

  pass "Adopted '$name' from $target_path"
  info "Next steps:"
  info "  1. Read design doc at $ws_dir/docs/design/README.md"
  info "  2. Fill in Purpose, Architecture, Components sections"
  info "  3. Run: bash scripts/workspace.sh gate $name INIT_TO_ACTIVE"
  info "  Note: Adopted projects get relaxed gates — design doc fill-in is the priority"
}

ws_list() {
  local catalog
  catalog=$(catalog_read)
  local count
  count=$(echo "$catalog" | jq 'length')

  echo ""
  echo "━━━ Workspaces ($count) ━━━"
  echo ""

  if [ "$count" -eq 0 ]; then
    info "No workspaces yet. Create one with: bash scripts/workspace.sh init <name>"
    echo ""
    return
  fi

  printf "  %-20s %-12s %-14s %s\n" "NAME" "STATE" "UPDATED" "PATH"
  echo "  $(printf '%0.s─' {1..75})"

  echo "$catalog" | jq -r 'to_entries[] | [.key, .value.state, .value.created, .value.path] | @tsv' |
  while IFS=$'\t' read -r name state created path; do
    if [ -d "$path" ]; then
      printf "  %-20s %-12s %-14s %s\n" "$name" "$state" "$created" "$path"
    else
      printf "  %-20s %-12s %-14s %s\n" "$name" "$state" "$created" "${YELLOW}MISSING${NC}"
    fi
  done

  echo ""
}

ws_state() {
  local name="$1"
  local ws_dir="$WORKSPACE_ROOT/$name"

  if [ ! -d "$ws_dir" ]; then
    fail "Workspace '$name' not found"
  fi
  if [ -f "$ws_dir/.kodehold-state" ]; then
    cat "$ws_dir/.kodehold-state"
  else
    info "No .kodehold-state found — workspace not initialized with lifecycle"
  fi
}

ws_transition() {
  local name="$1"
  local transition="$2"
  local ws_dir="$WORKSPACE_ROOT/$name"

  if [ ! -d "$ws_dir" ]; then
    fail "Workspace '$name' not found"
  fi

  # Run the gate from the workspace directory
  if [ -f "$GATE_SCRIPT" ]; then
    if (cd "$ws_dir" && bash "$WS_ROOT/$GATE_SCRIPT" --transition "$transition"); then
      pass "Gate $transition passed for '$name'"
    else
      fail "Gate $transition BLOCKED for '$name' — fix before transition"
    fi
  fi

  # Update state file
  local next_state
  case "$transition" in
    INIT_TO_ACTIVE)   next_state="ACTIVE" ;;
    ACTIVE_TO_REVIEW) next_state="REVIEW" ;;
    REVIEW_TO_CLOSED) next_state="CLOSED" ;;
    CLOSED_TO_REOPEN) next_state="REOPEN" ;;
    REOPEN_TO_ACTIVE) next_state="ACTIVE" ;;
    *) fail "Unknown transition: $transition" ;;
  esac

  sed -i "s/^STATE=.*/STATE=$next_state/" "$ws_dir/.kodehold-state"
  sed -i "s/^LAST_UPDATED=.*/LAST_UPDATED=$(date +%Y-%m-%d)/" "$ws_dir/.kodehold-state"

  # Update catalog
  local catalog
  catalog=$(catalog_read)
  catalog=$(echo "$catalog" | jq --arg n "$name" --arg s "$next_state" \
    '.[$n].state = $s | .[$n].updated = (now | strftime("%Y-%m-%d"))')
  catalog_write "$catalog"

  pass "Transitioned '$name' to $next_state"
}

ws_deploy_ready() {
  local name="$1"
  local ws_dir="$WORKSPACE_ROOT/$name"

  if [ ! -d "$ws_dir" ]; then
    fail "Workspace '$name' not found"
  fi

  local state
  state=$(grep "^STATE=" "$ws_dir/.kodehold-state" 2>/dev/null | cut -d= -f2)

  if [ "$state" = "CLOSED" ]; then
    pass "'$name' is CLOSED — ready for deploy"
    return 0
  else
    info "'$name' is $state — must reach CLOSED before deploy"
    info "  Current path: INIT → ACTIVE → REVIEW → CLOSED"
    return 1
  fi
}

usage() {
  echo "KodeHold Workspace Manager"
  echo ""
  echo "Usage: bash scripts/workspace.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  init <name>         Create a new project workspace from scratch"
  echo "  adopt <name> <path> Adopt an existing project (symlink + KodeHold bootstrap)"
  echo "  list                List all workspaces"
  echo "  state <name>        Show lifecycle state of a workspace"
  echo "  gate <name> <t>     Run a gate transition on a workspace"
  echo "  deploy-ready <name> Check if workspace is ready to deploy"
  echo ""
  echo "Transitions:"
  echo "  INIT_TO_ACTIVE, ACTIVE_TO_REVIEW, REVIEW_TO_CLOSED,"
  echo "  CLOSED_TO_REOPEN, REOPEN_TO_ACTIVE"
  echo ""
  exit 1
}

# Resolve script root so gates work relative to project root
WS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WS_ROOT"

case "${1:-}" in
  init)
    [ -n "${2:-}" ] || usage
    ws_init "$2"
    ;;
  adopt)
    [ -n "${3:-}" ] || usage
    ws_adopt "$2" "$3"
    ;;
  list)
    ws_list
    ;;
  state)
    [ -n "${2:-}" ] || usage
    ws_state "$2"
    ;;
  gate)
    [ -n "${3:-}" ] || usage
    ws_transition "$2" "$3"
    ;;
  deploy-ready)
    [ -n "${2:-}" ] || usage
    ws_deploy_ready "$2"
    ;;
  *) usage ;;
esac
