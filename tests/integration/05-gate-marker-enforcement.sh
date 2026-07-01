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

  mkdir -p "$project_dir/scripts" "$project_dir/docs/design" "$project_dir/docs/adr"
  cp "$ROOT_DIR/scripts/gate.sh" "$project_dir/scripts/gate.sh"
  mkdir -p "$project_dir/scripts/lib"
  cp "$ROOT_DIR/scripts/lib/output.sh" "$project_dir/scripts/lib/output.sh"

  cat > "$project_dir/docs/design/README.md" <<'EOF'
# Design
Status: Active
Last Updated: 2026-05-27

## Purpose & Scope
## Requirements
## Architecture Overview
## Component Design
## Data Model
## API Design
## Implementation Plan
## Testing Strategy
## ADR Index
## Open Questions
## Changelog
EOF

  cat > "$project_dir/docs/adr/README.md" <<'EOF'
# ADR Index
EOF

  cat > "$project_dir/docs/adr/ADR-0001-sample.md" <<'EOF'
# ADR-0001: Sample
EOF
}

# .design_reviewed enforcement
case_dir="$TMP_ROOT/case_design_enforcement"
setup_project "$case_dir"
if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition INIT_TO_ACTIVE >"out.log" 2>&1); then
  fail "INIT_TO_ACTIVE should fail without .design_reviewed"
fi
grep -q "Design not reviewed" "$case_dir/out.log" \
  && pass "INIT_TO_ACTIVE enforces .design_reviewed" \
  || fail "INIT_TO_ACTIVE missing .design_reviewed enforcement message"

# Cleanup timing for INIT_TO_ACTIVE (marker must survive cancellation)
case_dir="$TMP_ROOT/case_cleanup_timing"
setup_project "$case_dir"
touch "$case_dir/.design_reviewed"
touch "$case_dir/.second_opinion_done"
if (cd "$case_dir" && printf 'n\n' | env -u OPENCODE_NONINTERACTIVE bash "scripts/gate.sh" --transition INIT_TO_ACTIVE >"out.log" 2>&1); then
  fail "INIT_TO_ACTIVE should fail when user cancels"
fi
[ -f "$case_dir/.design_reviewed" ] \
  && pass ".design_reviewed retained when INIT_TO_ACTIVE is cancelled" \
  || fail ".design_reviewed removed before INIT_TO_ACTIVE passed"
[ -f "$case_dir/.second_opinion_done" ] \
  && pass ".second_opinion_done retained when INIT_TO_ACTIVE is cancelled" \
  || fail ".second_opinion_done removed before INIT_TO_ACTIVE passed"

# OPENCODE_NONINTERACTIVE prompt bypass + cleanup on pass
case_dir="$TMP_ROOT/case_noninteractive_env"
setup_project "$case_dir"
touch "$case_dir/.design_reviewed"
touch "$case_dir/.second_opinion_done"
(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition INIT_TO_ACTIVE >"out.log" 2>&1) \
  && pass "OPENCODE_NONINTERACTIVE bypasses INIT_TO_ACTIVE prompt" \
  || fail "OPENCODE_NONINTERACTIVE INIT_TO_ACTIVE run failed"
grep -q "Proceed with INIT → ACTIVE\?" "$case_dir/out.log" \
  && fail "Prompt should be skipped in OPENCODE_NONINTERACTIVE mode" \
  || pass "Prompt skipped when OPENCODE_NONINTERACTIVE is set"
[ ! -f "$case_dir/.design_reviewed" ] \
  && pass ".design_reviewed removed only after INIT_TO_ACTIVE passed" \
  || fail ".design_reviewed not cleaned after successful INIT_TO_ACTIVE"
[ ! -f "$case_dir/.second_opinion_done" ] \
  && pass ".second_opinion_done removed only after INIT_TO_ACTIVE passed" \
  || fail ".second_opinion_done not cleaned after successful INIT_TO_ACTIVE"

# --yes prompt bypass + cleanup on pass
case_dir="$TMP_ROOT/case_yes_flag"
setup_project "$case_dir"
touch "$case_dir/.design_reviewed"
touch "$case_dir/.second_opinion_done"
(cd "$case_dir" && bash "scripts/gate.sh" --yes --transition INIT_TO_ACTIVE >"out.log" 2>&1) \
  && pass "--yes bypasses INIT_TO_ACTIVE prompt" \
  || fail "--yes INIT_TO_ACTIVE run failed"
grep -q "Proceed with INIT → ACTIVE\?" "$case_dir/out.log" \
  && fail "Prompt should be skipped when using --yes" \
  || pass "Prompt skipped when using --yes"
[ ! -f "$case_dir/.design_reviewed" ] \
  && pass ".design_reviewed cleaned after --yes pass" \
  || fail ".design_reviewed not cleaned after --yes pass"
[ ! -f "$case_dir/.second_opinion_done" ] \
  && pass ".second_opinion_done cleaned after --yes pass" \
  || fail ".second_opinion_done not cleaned after --yes pass"

# .impact_analysis_done enforcement + cleanup
case_dir="$TMP_ROOT/case_impact_marker"
setup_project "$case_dir"
if (cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition CLOSED_TO_REOPEN >"out_missing.log" 2>&1); then
  fail "CLOSED_TO_REOPEN should fail without .impact_analysis_done"
fi
grep -q "Impact analysis not completed" "$case_dir/out_missing.log" \
  && pass "CLOSED_TO_REOPEN enforces .impact_analysis_done" \
  || fail "CLOSED_TO_REOPEN missing .impact_analysis_done enforcement message"

touch "$case_dir/.impact_analysis_done"
(cd "$case_dir" && OPENCODE_NONINTERACTIVE=true bash "scripts/gate.sh" --transition CLOSED_TO_REOPEN >"out_pass.log" 2>&1) \
  && pass "CLOSED_TO_REOPEN passes with .impact_analysis_done" \
  || fail "CLOSED_TO_REOPEN should pass with .impact_analysis_done"
[ ! -f "$case_dir/.impact_analysis_done" ] \
  && pass ".impact_analysis_done removed only after CLOSED_TO_REOPEN passed" \
  || fail ".impact_analysis_done not cleaned after successful CLOSED_TO_REOPEN"

