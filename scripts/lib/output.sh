# Shared output formatting for KodeHold scripts
# Source: scripts/lib/output.sh
# Override fail() locally if exit-on-failure is needed.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { [ "${JSON_MODE:-false}" = true ] || echo -e "  ${GREEN}✓${NC} $1"; return 0; }
fail() { [ "${JSON_MODE:-false}" = true ] || echo -e "  ${RED}✗${NC} $1"; return 0; }
warn() { [ "${JSON_MODE:-false}" = true ] || echo -e "  ${YELLOW}⚠${NC} $1"; return 0; }
info() { [ "${JSON_MODE:-false}" = true ] || echo -e "  ${CYAN}i${NC} $1"; return 0; }

# ── JSON output helpers ────────────────────────────────────────────────────
# Usage:
#   source scripts/lib/output.sh
#   JSON_CHECKS=()
#   json_add "check_name" "PASS"
#   json_add "check_name" "FAIL" "optional detail message"
#   json_emit "script_name" "PASS|BLOCKED|FAILED" [version] [transition]
#
# When JSON_MODE=true, pass/fail/warn are silenced (use json_add instead).

# ── Self-modification detection ──────────────────────────────────────────
# KodeHold self-modification system paths — if changes are detected to any
# of these files, the gate system assumes KodeHold is modifying itself and
# skips quality checks (avoiding circular self-gating).
KODEHOLD_SYSTEM_PATHS=(
  "scripts/gate.py"
  "scripts/gate.sh"
  "scripts/ship.py"
  "scripts/ship.sh"
  "scripts/workspace.py"
  "scripts/workspace.sh"
  "scripts/lib/output.py"
  "scripts/lib/output.sh"
  "scripts/validate_config.py"
  "scripts/sync_agent_config.py"
  ".opencode/agents/"
  "config/agents.yaml"
  "opencode.json"
  "opencode-rag.json"
  "AGENTS.md"
)

# Check whether the gate is running on KodeHold itself (self-modification).
# Returns 0 (true) if self-modification is detected, 1 (false) otherwise.
# Detection order: env var → marker file → git diff on system paths.
is_self_modification() {
  # 1. Explicit environment variable
  if [ "${KODEHOLD_SELF_MODE:-}" = "1" ]; then
    return 0
  fi

  # 2. Marker file in project root
  if [ -f ".kodehold-self-mode" ]; then
    return 0
  fi

  # 3. Auto-detection: only in the KodeHold root (gate scripts exist) AND
  #    no --project-path was given (meaning we're not checking a workspace)
  if [ -f "scripts/gate.sh" ] && [ -z "${PROJECT_PATH:-}" ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
      local changed_files
      changed_files="$(git diff --name-only HEAD 2>/dev/null || git diff --name-only 2>/dev/null || true)"
      if [ -n "$changed_files" ]; then
        local pattern
        for pattern in "${KODEHOLD_SYSTEM_PATHS[@]}"; do
          if echo "$changed_files" | grep -qE "^${pattern}"; then
            return 0
          fi
        done
      fi
    fi
  fi

  return 1
}

JSON_CHECKS=()
json_add() {
  local name="$1" status="$2" detail="${3:-}"
  if [ -n "$detail" ]; then
    JSON_CHECKS+=("$(printf '{"name":"%s","result":"%s","detail":"%s"}' "$name" "$status" "$(echo "$detail" | sed 's/"/\\"/g')")")
  else
    JSON_CHECKS+=("$(printf '{"name":"%s","result":"%s"}' "$name" "$status")")
  fi
}

json_emit() {
  local script="$1" result="$2" version="${3:-}" transition="${4:-}"
  local checks_json
  checks_json=$(IFS=,; echo "${JSON_CHECKS[*]}")
  local json='{"script":"'"$script"'","result":"'"$result"'"'
  [ -n "$version" ]    && json+=',"version":"'"$version"'"'
  [ -n "$transition" ] && json+=',"transition":"'"$transition"'"'
  json+=',"checks":['"$checks_json"']}'
  echo "$json"
}
