#!/usr/bin/env bash
# DEPRECATED — Phase 3 (ADR-0031). Agentmemory auto-consolidates via its 4-tier
# pipeline (working → episodic → semantic → procedural). Manual consolidation is
# no longer needed. The agentmemory daemon handles consolidation automatically.
# This script is preserved for reference but should not be executed.
# =============================================================================

echo "WARNING: This script is deprecated. Agentmemory auto-consolidates via its 4-tier pipeline."
echo "Run agentmemory doctor for agentmemory diagnostics instead."
exit 0
# KodeHold ICM Consolidation — automatically consolidate ICM topics with too many entries
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
info() { echo -e "  ${CYAN}i${NC} $1"; }

# ------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------
THRESHOLD=5
DRY_RUN=false

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --threshold=*)
      THRESHOLD="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--threshold N]"
      echo ""
      echo "Automatically consolidate ICM topics with too many entries."
      echo ""
      echo "Options:"
      echo "  --dry-run           Show what would be consolidated without doing it"
      echo "  --threshold N       Consolidate topics with more than N entries (default: 5)"
      echo "  -h, --help          Show this help message"
      echo ""
      echo "Exit codes:"
      echo "  0   All OK"
      echo "  1   One or more consolidation errors"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run] [--threshold N]"
      exit 1
      ;;
  esac
done

# ------------------------------------------------------------------
# Validate threshold
# ------------------------------------------------------------------
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "Error: --threshold must be a positive integer, got '$THRESHOLD'"
  exit 1
fi

# ------------------------------------------------------------------
# Check prerequisites
# ------------------------------------------------------------------
echo -e "${YELLOW}⚠ WARNING: This script consolidates the deprecated ICM system.${NC}"
echo -e "${YELLOW}  Agentmemory auto-consolidates — this script is no longer needed.${NC}"
echo ""
if ! command -v icm &>/dev/null; then
  echo "Error: 'icm' CLI not found — is ICM installed?"
  exit 1
fi

# ------------------------------------------------------------------
# Header
# ------------------------------------------------------------------
echo ""
echo "═══ ICM Consolidation ════════════════════════════════════════════════════"
echo "  Threshold: > $THRESHOLD entries"
echo "  Mode:      $("$DRY_RUN" && echo 'DRY RUN (no changes)' || echo 'LIVE')"
echo ""

# ------------------------------------------------------------------
# Fetch all topics with counts
# ------------------------------------------------------------------
TOPICS_RAW=$(icm topics 2>&1) || {
  echo "Error: 'icm topics' failed"
  echo "$TOPICS_RAW"
  exit 1
}

# Parse: skip header (line 1) and separator (line 2), extract name and count
# Topic names use kebab-case (no spaces), so $1 = name, $NF = count
mapfile -t TOPIC_LINES < <(echo "$TOPICS_RAW" | awk 'NR>2 && NF>=2 {print $1, $NF}')

# ------------------------------------------------------------------
# Classify topics
# ------------------------------------------------------------------
declare -a TO_CONSOLIDATE=()
declare -a TO_SKIP=()
TOTAL_TOPICS=0

for entry in "${TOPIC_LINES[@]}"; do
  [ -z "$entry" ] && continue
  TOTAL_TOPICS=$((TOTAL_TOPICS + 1))

  name="${entry%% *}"
  count="${entry##* }"

  if [ "$count" -le "$THRESHOLD" ]; then
    TO_SKIP+=("$name")
  else
    TO_CONSOLIDATE+=("$name ($count entries)")
  fi
done

# ------------------------------------------------------------------
# Execute consolidation
# ------------------------------------------------------------------
declare -a CONSOLIDATED=()
declare -a ERRORS=()

if [ "${#TO_CONSOLIDATE[@]}" -eq 0 ]; then
  echo "  No topics exceed the threshold of $THRESHOLD entries."
  echo ""
fi

for topic_info in "${TO_CONSOLIDATE[@]}"; do
  topic="${topic_info%% (*}"
  count_info="${topic_info#*\(}"
  count_val="${count_info% entries*}"

  echo "  Consolidating: $topic ($count_val entries)"

  if [ "$DRY_RUN" = true ]; then
    CONSOLIDATED+=("$topic ($count_val entries → 1)")
    echo "    [dry-run] skipped"
  else
    if output=$(icm consolidate --topic "$topic" 2>&1); then
      CONSOLIDATED+=("$topic ($count_val entries → 1)")
      # Extract the consolidation ID from output for the report line
      id=$(echo "$output" | grep -oP "(?<=into )[^ ]+" || echo "?")
      pass "Consolidated → $id"
    else
      ERRORS+=("$topic: $output")
      fail "Consolidation failed"
    fi
  fi
done

# ------------------------------------------------------------------
# Report
# ------------------------------------------------------------------
echo ""
echo "═══ ICM Consolidation Report ═════════════════════════════════════════════"
echo "Topics scanned:       $TOTAL_TOPICS"
echo "Topics consolidated:  ${#CONSOLIDATED[@]}"
echo "Topics skipped (<$THRESHOLD): ${#TO_SKIP[@]}"
echo "Errors:               ${#ERRORS[@]}"
echo "──────────────────────────────────────────────────────────────────────────"

if [ "${#CONSOLIDATED[@]}" -gt 0 ]; then
  echo "Consolidated:"
  for item in "${CONSOLIDATED[@]}"; do
    echo "  - $item"
  done
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  echo "Errors:"
  for item in "${ERRORS[@]}"; do
    echo "  - $item"
  done
fi

echo "══════════════════════════════════════════════════════════════════════════"
echo ""

# ------------------------------------------------------------------
# Exit code
# ------------------------------------------------------------------
[ "${#ERRORS[@]}" -gt 0 ] && exit 1 || exit 0
