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
