#!/usr/bin/env bash
# DEPRECATED — Phase 3 (ADR-0031). This script benchmarks ICM (Infinite Context Memory),
# which has been replaced by agentmemory per ADR-0029. Agentmemory has no equivalent
# benchmarking CLI. Metrics are now collected via agentmemory_memory_diagnose() and
# token-usage.sh. This script is preserved for reference but should not be used.
# =============================================================================
# KodeHold ICM Performance Benchmarks
# Measures real-world ICM operation speeds and reports results as a table.
# Usage: bash scripts/benchmark.sh [--quick] [--full] [--topic <name>]
#   --quick   Minimal run: 10 real-world ops + 50 micro-bench ops
#   --full    Full run: 50 real-world ops + 200 micro-bench ops (default)
#   --topic   Topic to test consolidation on (default: benchmark-test)

set -euo pipefail

# Defaults
MICRO_OPS=200
REAL_OPS=50
CONSOLIDATE_SEED=30
CONSOLIDATE_TOPIC="benchmark-test"
MODE="full"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick)
      MODE="quick"
      MICRO_OPS=50
      REAL_OPS=5
      CONSOLIDATE_SEED=10
      shift
      ;;
    --full)
      MODE="full"
      MICRO_OPS=200
      REAL_OPS=50
      shift
      ;;
    --topic)
      CONSOLIDATE_TOPIC="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--quick|--full] [--topic <name>]"
      echo "  --quick   5 real-world ops + 50 micro-bench ops (fast)"
      echo "  --full    50 real-world ops + 200 micro-bench ops (default)"
      echo "  --topic   Topic for consolidation test (default: benchmark-test)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Verify ICM is available
echo -e "${YELLOW}⚠ WARNING: This script benchmarks the deprecated ICM system.${NC}"
echo -e "${YELLOW}  Agentmemory has replaced ICM. Use scripts/token-usage.sh and${NC}"
echo -e "${YELLOW}  agentmemory_memory_diagnose() for current metrics.${NC}"
echo ""
if ! command -v icm >/dev/null 2>&1; then
  echo -e "${RED}ERROR: icm binary not found${NC}" >&2
  exit 1
fi

# Header
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          KodeHold ICM Performance Benchmarks (${MODE})            ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${DIM}Mode:${NC}         ${BOLD}${MODE}${NC}"
echo -e "  ${DIM}Micro-bench:${NC}  ${MICRO_OPS} ops (in-memory, no embeddings)"
echo -e "  ${DIM}Real-world:${NC}   ${REAL_OPS} ops (on-disk DB with embeddings)"
echo -e "  ${DIM}Consolidation:${NC} topic '${CONSOLIDATE_TOPIC}'"
echo ""

# ── Part A: Built-in Micro-Benchmarks (fast, in-memory) ──
echo -e "${BOLD}${GREEN}▸ Part A: Micro-Benchmarks (in-memory store, no embeddings)${NC}"
echo -e "  ${DIM}These measure raw ICM engine throughput without I/O overhead.${NC}"
echo ""
icm bench --count "$MICRO_OPS" --no-embeddings 2>&1
echo ""

# ── Part B: Real-World Benchmarks (on-disk DB with embeddings) ──
echo -e "${BOLD}${GREEN}▸ Part B: Real-World Benchmarks (on-disk DB with embeddings)${NC}"
echo -e "  ${DIM}These measure actual I/O latency including vector embeddings.${NC}"
echo ""

# ── B1: Recall speed ──
echo -e "  ${BOLD}B1: ICM Recall (FTS5 + vector search)${NC}"
echo -e "  ${DIM}Running ${REAL_OPS} recall queries...${NC}"

RECALL_START=$(date +%s%N)
for i in $(seq 1 "$REAL_OPS"); do
  icm recall "benchmark query $i" --limit 5 >/dev/null 2>&1
done
RECALL_END=$(date +%s%N)
RECALL_MS=$(( (RECALL_END - RECALL_START) / 1000000 ))
if [[ "$RECALL_MS" -gt 0 ]]; then
  RECALL_US_OP=$(awk "BEGIN {printf \"%.0f\", ($REAL_OPS * 1000000) / $RECALL_MS}")
  RECALL_MS_PER_OP=$(awk "BEGIN {printf \"%.1f\", $RECALL_MS / $REAL_OPS}")
else
  RECALL_US_OP="N/A"
  RECALL_MS_PER_OP="N/A"
fi

B1_NAME="Recall (FTS5+vector)"
B1_OPS="$REAL_OPS"
B1_MS="$RECALL_MS"
B1_PER_OP="${RECALL_MS_PER_OP}ms/op"
echo -e "  ${DIM}Done: ${RECALL_MS}ms total, ~${RECALL_MS_PER_OP}ms/op${NC}"
echo ""

# ── B2: Store speed ──
echo -e "  ${BOLD}B2: ICM Store (write + embed)${NC}"
echo -e "  ${DIM}Running ${REAL_OPS} store operations...${NC}"

STORE_START=$(date +%s%N)
for i in $(seq 1 "$REAL_OPS"); do
  icm store --topic "benchmark-perf" \
    --content "Performance benchmark entry $i at $(date +%s%N)" \
    --importance low --keywords bench,perf 2>/dev/null
done
STORE_END=$(date +%s%N)
STORE_MS=$(( (STORE_END - STORE_START) / 1000000 ))
if [[ "$STORE_MS" -gt 0 ]]; then
  STORE_US_OP=$(awk "BEGIN {printf \"%.0f\", ($REAL_OPS * 1000000) / $STORE_MS}")
  STORE_MS_PER_OP=$(awk "BEGIN {printf \"%.1f\", $STORE_MS / $REAL_OPS}")
else
  STORE_US_OP="N/A"
  STORE_MS_PER_OP="N/A"
fi

B2_NAME="Store (write+embed)"
B2_OPS="$REAL_OPS"
B2_MS="$STORE_MS"
B2_PER_OP="${STORE_MS_PER_OP}ms/op"
echo -e "  ${DIM}Done: ${STORE_MS}ms total, ~${STORE_MS_PER_OP}ms/op${NC}"
echo ""

# ── B3: Recall-context speed ──
echo -e "  ${BOLD}B3: ICM Recall-Context (prompt injection format)${NC}"
CTX_OPS=$((REAL_OPS / 5))
if [[ "$CTX_OPS" -lt 5 ]]; then CTX_OPS=5; fi
echo -e "  ${DIM}Running ${CTX_OPS} recall-context operations...${NC}"

CTX_START=$(date +%s%N)
for i in $(seq 1 "$CTX_OPS"); do
  icm recall-context "implementation patterns" --limit 5 >/dev/null 2>&1
done
CTX_END=$(date +%s%N)
CTX_MS=$(( (CTX_END - CTX_START) / 1000000 ))
if [[ "$CTX_MS" -gt 0 ]]; then
  CTX_US_OP=$(awk "BEGIN {printf \"%.0f\", ($CTX_OPS * 1000000) / $CTX_MS}")
  CTX_MS_PER_OP=$(awk "BEGIN {printf \"%.1f\", $CTX_MS / $CTX_OPS}")
else
  CTX_US_OP="N/A"
  CTX_MS_PER_OP="N/A"
fi

B3_NAME="Recall-context"
B3_OPS="$CTX_OPS"
B3_MS="$CTX_MS"
B3_PER_OP="${CTX_MS_PER_OP}ms/op"
echo -e "  ${DIM}Done: ${CTX_MS}ms total, ~${CTX_MS_PER_OP}ms/op${NC}"
echo ""

# ── B4: Consolidation speed ──
echo -e "  ${BOLD}B4: ICM Consolidation${NC}"
echo -e "  ${DIM}Seeding topic '${CONSOLIDATE_TOPIC}' with ${CONSOLIDATE_SEED} entries...${NC}"

for i in $(seq 1 "$CONSOLIDATE_SEED"); do
  icm store --topic "$CONSOLIDATE_TOPIC" \
    --content "Consolidation test entry $i: $(date +%s%N) random data for merge" \
    --importance low --keywords bench,consolidate >/dev/null 2>&1
done

echo -e "  ${DIM}Running consolidation...${NC}"
CONSOLIDATE_START=$(date +%s%N)
icm consolidate --topic "$CONSOLIDATE_TOPIC" >/dev/null 2>&1
CONSOLIDATE_END=$(date +%s%N)
CONSOLIDATE_MS=$(( (CONSOLIDATE_END - CONSOLIDATE_START) / 1000000 ))

B4_NAME="Consolidate (${CONSOLIDATE_SEED}→1)"
B4_OPS="1"
B4_MS="$CONSOLIDATE_MS"
B4_PER_OP="N/A"
echo -e "  ${DIM}Done: ${CONSOLIDATE_MS}ms total${NC}"

# Cleanup
icm forget --topic "$CONSOLIDATE_TOPIC" 2>/dev/null || true
echo ""

# ── Part C: Summary Table ──
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                        SUMMARY TABLE                           ║${NC}"
echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
printf "║ ${BOLD}%-28s %8s  %10s  %12s${NC} ║\n" "Operation" "Ops" "Total ms" "Per Op"
echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"

for idx in 1 2 3 4; do
  eval "name=\${B${idx}_NAME}"
  eval "ops=\${B${idx}_OPS}"
  eval "ms=\${B${idx}_MS}"
  eval "per_op=\${B${idx}_PER_OP}"
  printf "║ %-28s %8s  %10s  %12s ║\n" "$name" "$ops" "${ms}" "$per_op"
done

echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${CYAN}║  Platform:  $(uname -m)-$(uname -s)                                ║${NC}"
echo -e "${BOLD}${CYAN}║  Date:      $(date -u '+%Y-%m-%d %H:%M:%S UTC')                          ║${NC}"
echo -e "${BOLD}${CYAN}║  Mode:      ${MODE}                                                 ║${NC}"
echo -e "${BOLD}${CYAN}║  Embeddings: ON (real-world latency includes vector computation)  ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
