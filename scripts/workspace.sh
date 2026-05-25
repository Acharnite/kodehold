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
  echo "  init <name>         Create a new project workspace"
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
