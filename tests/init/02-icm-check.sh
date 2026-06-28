#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; }


# Verify .opencode/memory/ directory structure exists
if [ -d .opencode/memory ]; then
  pass ".opencode/memory/ directory exists"
else
  warn ".opencode/memory/ not found — create with mkdir -p .opencode/memory/{decisions,patterns,lessons,metrics,checkpoints,prospective}"
fi

# Verify key subdirectories exist
for dir in decisions patterns lessons metrics checkpoints prospective; do
  if [ -d ".opencode/memory/$dir" ]; then
    :
  else
    warn ".opencode/memory/$dir/ not found"
  fi
done

