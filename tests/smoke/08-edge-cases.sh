#!/usr/bin/env bash
# Phase 5 — Edge case and robustness tests
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# ── 1. opencode.json is valid JSON ────────────────────────────────
if python3 -m json.tool "$SCRIPT_DIR/opencode.json" >/dev/null 2>&1; then
  pass "opencode.json is valid JSON"
else
  fail "opencode.json is not valid JSON"
fi

# ── 2. .kodehold-state contains required fields ──────────────────
state_file="$SCRIPT_DIR/.kodehold-state"
if [ ! -f "$state_file" ]; then
  fail ".kodehold-state missing"
else
  missing_fields=0
  for field in STATE LAST_UPDATED; do
    if grep -q "^${field}=" "$state_file" 2>/dev/null; then
      val=$(grep "^${field}=" "$state_file" | cut -d= -f2-)
      [ -n "$val" ] && pass ".kodehold-state $field = $val" || {
        echo "    $field is empty in .kodehold-state"
        missing_fields=$((missing_fields + 1))
      }
    else
      echo "    $field not found in .kodehold-state"
      missing_fields=$((missing_fields + 1))
    fi
  done
  state_val=$(grep "^STATE=" "$state_file" | cut -d= -f2-)
  case "$state_val" in
    INIT|ACTIVE|REVIEW|CLOSED|REOPEN)
      pass ".kodehold-state STATE is valid: $state_val"
      ;;
    *)
      fail ".kodehold-state STATE invalid: '$state_val'"
      ;;
  esac
  if [ "$missing_fields" -eq 0 ]; then
    pass ".kodehold-state has all required fields"
  else
    fail ".kodehold-state missing $missing_fields required field(s)"
  fi
fi

# ── 3. VERSION.md parses correctly ──────────────────────────
version_file="$SCRIPT_DIR/VERSION.md"
if [ ! -f "$version_file" ]; then
  fail "VERSION.md missing"
else
  tables=$(grep -c '^| *---' "$version_file" 2>/dev/null || true)
  pass "VERSION.md has $tables table(s)"

  data_rows=$(grep -cP '^\| *[\d]+\.[\d]+\.[\d]+' "$version_file" 2>/dev/null || true)
  if [ "$data_rows" -gt 0 ]; then
    pass "VERSION.md has $data_rows version data rows"
  else
    fail "VERSION.md has no version data rows"
  fi
fi

# ── 4. .gitignore contains key entries ────────────────────────────
gitignore="$SCRIPT_DIR/.gitignore"
if [ ! -f "$gitignore" ]; then
  fail ".gitignore missing"
else
  missing_entries=0
  for entry in '*.pyc' '__pycache__' '.venv'; do
    if grep -q "^$entry$" "$gitignore" 2>/dev/null; then
      pass ".gitignore contains: $entry"
    else
      echo "    MISSING from .gitignore: $entry"
      missing_entries=$((missing_entries + 1))
    fi
  done
  if [ "$missing_entries" -eq 0 ]; then
    pass ".gitignore has all key entries"
  else
    fail ".gitignore missing $missing_entries key entry/entries"
  fi
fi

# ── 5. config/agents.schema.json is valid JSON Schema ────────────
schema_file="$SCRIPT_DIR/config/agents.schema.json"
if [ ! -f "$schema_file" ]; then
  fail "config/agents.schema.json missing"
else
  if python3 -m json.tool "$schema_file" >/dev/null 2>&1; then
    pass "agents.schema.json is valid JSON"
  else
    fail "agents.schema.json is not valid JSON"
  fi

  schema_draft=$(python3 -c "
import json
with open('$schema_file') as f:
    schema = json.load(f)
print(schema.get('\$schema', 'unknown'))
" 2>/dev/null)
  if echo "$schema_draft" | grep -qE 'json-schema\.org/draft-0[4-9]'; then
    pass "Schema draft: $schema_draft"
  else
    pass "Schema \$schema: $schema_draft"
  fi
fi
