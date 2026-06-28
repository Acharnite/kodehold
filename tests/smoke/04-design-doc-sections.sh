#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }


dd="docs/design/README.md"
[ -f "$dd" ] || fail "$dd not found"

sections=("Purpose & Scope" "Architecture Overview" "Organizational Structure"
          "Design Document Lifecycle" "Architecture Decision Records"
          "Project Lifecycle" "Integration" "LLM Support"
          "Token Optimization Strategy" "File Layout")

for s in "${sections[@]}"; do
  grep -q "^## .*$s" "$dd" && pass "Section: $s" || fail "Missing section: $s"
done

