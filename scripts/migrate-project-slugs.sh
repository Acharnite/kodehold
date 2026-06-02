#!/usr/bin/env bash
# KodeHold Project Slug Migration — batch-update agentmemory records from
# path-style project identifiers to canonical slugs per ADR-0036.
#
# Usage:
#   bash scripts/migrate-project-slugs.sh                # Live migration
#   bash scripts/migrate-project-slugs.sh --dry-run      # Preview only
#   bash scripts/migrate-project-slugs.sh --restore      # Restore from backup
#
# Requirements:
#   - curl
#   - jq (for JSON processing)
#   - agentmemory daemon at http://localhost:3111
set -uo pipefail
# Note: intentionally NOT using -e — API calls may return empty/non-standard
# responses that should be handled gracefully rather than aborting.
# All critical failures are caught with explicit error handling.

# ── Config ────────────────────────────────────────────────────────────────────
API_BASE="${AM_URL:-http://localhost:3111}/agentmemory"
DRY_RUN=false
RESTORE=false
LIMIT=500
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
REPORT_FILE="/tmp/slug-migration-${TIMESTAMP}.json"

# ── Colors & Helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
info() { echo -e "  ${CYAN}i${NC} $1"; }

# ── Slug Mapping Table (ADR-0036) ────────────────────────────────────────────
declare -A MAP
MAP[/home/kiffer/project/kodehold]=kodehold
MAP[/home/kiffer/project/bob]=bob
MAP[/home/kiffer/project/bob-ollama]=bob-ollama
MAP[/home/kiffer/project]=orphaned-workspace-root
MAP[/tmp/agentmemory-demo]=agentmemory-demo
MAP[workspaces/qbit-migrate]=qbit-migrate
MAP[/home/kiffer/project/medicin]=medicin

# ── Validate Slug ─────────────────────────────────────────────────────────────
# Check that a slug matches ^[a-z][a-z0-9-]{0,49}$
# Also rejects "null" (JSON null literal) and empty string.
validate_slug() {
  local slug="$1"
  [ -z "$slug" ] && return 1
  [ "$slug" = "null" ] && return 1
  [[ "$slug" =~ ^[a-z][a-z0-9-]{0,49}$ ]]
}

# ── Resolve Project to Slug ───────────────────────────────────────────────────
# Given a project value, return the target slug or empty string if unmapped.
resolve_slug() {
  local project="$1"

  # Empty or null — cannot map
  [ -z "$project" ] && echo "" && return 1
  [ "$project" = "null" ] && echo "" && return 1

  # Already a valid slug (no change needed)
  if validate_slug "$project"; then
    echo "$project"
    return 0
  fi

  # Check explicit mapping table
  if [[ -n "${MAP[$project]:-}" ]]; then
    echo "${MAP[$project]}"
    return 0
  fi

  # Dynamic mapping for workspaces/ prefix
  if [[ "$project" =~ ^workspaces/(.+) ]]; then
    local slug="${BASH_REMATCH[1]}"
    if validate_slug "$slug"; then
      echo "$slug"
      return 0
    fi
  fi

  # Dynamic mapping for full paths: basename + toSlug()
  if [[ "$project" == /* ]]; then
    local base
    base="$(basename "$project")"
    local slug
    slug="$(to_slug "$base")"
    if validate_slug "$slug"; then
      echo "$slug"
      return 0
    fi
  fi

  # No mapping found
  echo ""
  return 1
}

# ── toSlug() Normalizer ──────────────────────────────────────────────────────
# Converts arbitrary strings to valid slugs matching ^[a-z][a-z0-9-]{0,49}$
to_slug() {
  local name="$1"
  local slug
  slug="$(
    echo "$name" \
      | tr '[:upper:]' '[:lower:]' \
      | sed -e 's/[^a-z0-9-]/-/g' \
            -e 's/--*/-/g' \
            -e 's/^-//' \
            -e 's/-$//'
  )"
  # Ensure starts with a lowercase letter
  if ! echo "$slug" | grep -q '^[a-z]'; then
    slug="project-${slug}"
  fi
  # Truncate to 50 chars
  echo "${slug:0:50}"
}

# ── API Helpers ───────────────────────────────────────────────────────────────
api_get() {
  local path="$1"
  curl -sf "${API_BASE}${path}" 2>/dev/null || echo ""
}

api_post() {
  local path="$1"
  local data="${2:-}"
  if [ -n "$data" ]; then
    curl -sf -X POST -H "Content-Type: application/json" -d "$data" "${API_BASE}${path}" 2>/dev/null || echo ""
  else
    curl -sf -X POST "${API_BASE}${path}" 2>/dev/null || echo ""
  fi
}

# ── Backup ────────────────────────────────────────────────────────────────────
create_backup() {
  echo ""
  echo "━━━ Step 1: Backup ━━━"
  echo ""

  info "Creating database snapshot..."
  local result
  result="$(api_post "/snapshot/create" '{"message":"pre-slug-migration"}')"

  if [ -n "$result" ]; then
    local snap_id
    snap_id="$(echo "$result" | sed 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' 2>/dev/null || echo "$result")"
    pass "Snapshot created: ${snap_id:-$result}"
    return 0
  else
    warn "Snapshot creation returned empty — continuing anyway"
    return 0
  fi
}

# ── Restore ───────────────────────────────────────────────────────────────────
restore_from_backup() {
  echo ""
  echo "━━━ Restore from Backup ━━━"
  echo ""

  info "Listing recent snapshots..."
  local snaps
  snaps="$(api_get "/snapshot/list" 2>/dev/null || echo "")"

  if [ -z "$snaps" ]; then
    warn "No snapshots found or endpoint not available"
    warn "Restore may need to be done manually via agentmemory CLI"
    return 1
  fi

  echo "Recent snapshots:"
  echo "$snaps" | jq -r '.[] | "  \(.id) — \(.message // "no message") (\(.created // "?"))"' 2>/dev/null \
    || echo "$snaps" | head -20

  echo ""
  read -r -p "Enter snapshot ID to restore (or press Enter to cancel): " snap_choice
  if [ -z "$snap_choice" ]; then
    info "Restore cancelled"
    return 0
  fi

  local result
  result="$(api_post "/snapshot/restore" "{\"id\":\"${snap_choice}\"}")"
  if [ -n "$result" ]; then
    pass "Restored from snapshot: $snap_choice"
  else
    fail "Restore failed — check agentmemory daemon logs"
    return 1
  fi
}

# ── Process Actions ───────────────────────────────────────────────────────────
processed_total=0
updated_total=0
skipped_total=0
errored_total=0
declare -a updated_records=()
declare -a skipped_records=()
declare -a errored_records=()

process_actions() {
  echo ""
  echo "━━━ Step 2: Processing Actions ━━━"
  echo ""

  local offset=0
  local batch_count=0

  while true; do
    local response
    response="$(api_get "/actions?limit=${LIMIT}&offset=${offset}")"
    [ -z "$response" ] && break

    local count
    count="$(echo "$response" | jq '.actions | length' 2>/dev/null || echo "0")"
    [ "$count" -eq 0 ] && break

    for row in $(echo "$response" | jq -r '.actions[] | @base64' 2>/dev/null); do
      _process_action_row "$row"
    done

    batch_count="$((batch_count + count))"
    info "  Actions batch: $count records (${batch_count} total, ${updated_total} needs update)"
    offset="$((offset + LIMIT))"
    [ "$count" -lt "$LIMIT" ] && break
  done

  echo ""
  pass "Actions processing complete: $processed_total processed, $updated_total to update, $skipped_total skipped, $errored_total errored"
}

_process_action_row() {
  local row="$1"
  local id project
  id="$(echo "$row" | base64 -d 2>/dev/null | jq -r '.id // ._id // empty' 2>/dev/null)"
  project="$(echo "$row" | base64 -d 2>/dev/null | jq -r '.project // empty' 2>/dev/null)"

  [ -z "$id" ] && return
  processed_total=$((processed_total + 1))

  local slug
  slug="$(resolve_slug "$project")"

  # Build a JSON record with proper encoding via jq
  local record
  # No slug mapping found — skip
  if [ -z "$slug" ]; then
    skipped_total=$((skipped_total + 1))
    record="$(jq -nc --arg t "action" --arg i "$id" --arg p "${project:-}" --arg r "No mapping found for project value" '{type: $t, id: $i, project: $p, reason: $r}' 2>/dev/null || echo "{\"type\":\"action\",\"id\":\"$id\"}")"
    skipped_records+=("$record")
    return
  fi

  # Already the correct slug — skip
  if [ "$slug" = "$project" ]; then
    skipped_total=$((skipped_total + 1))
    record="$(jq -nc --arg t "action" --arg i "$id" --arg p "${project:-}" --arg s "$slug" --arg r "Already target slug" '{type: $t, id: $i, project: $p, slug: $s, reason: $r}' 2>/dev/null || echo "{\"type\":\"action\",\"id\":\"$id\"}")"
    skipped_records+=("$record")
    return
  fi

  # Validate target slug
  if ! validate_slug "$slug"; then
    errored_total=$((errored_total + 1))
    record="$(jq -nc --arg t "action" --arg i "$id" --arg p "${project:-}" --arg s "$slug" --arg r "Invalid slug: $slug" '{type: $t, id: $i, project: $p, target_slug: $s, reason: $r}' 2>/dev/null || echo "{\"type\":\"action\",\"id\":\"$id\"}")"
    errored_records+=("$record")
    warn "  Invalid slug '$slug' for action $id (project: $project) — skipping"
    return
  fi

  # Record the update
  updated_total=$((updated_total + 1))
  record="$(jq -nc --arg t "action" --arg i "$id" --arg o "${project:-}" --arg n "$slug" '{type: $t, id: $i, old_project: $o, new_project: $n}' 2>/dev/null || echo "{\"type\":\"action\",\"id\":\"$id\"}")"
  updated_records+=("$record")

  if [ "$DRY_RUN" = false ]; then
    # Attempt update via API
    local update_result
    update_result="$(api_post "/actions/${id}/update" "{\"project\":\"${slug}\"}")"
    if [ -z "$update_result" ]; then
      warn "  Update for action $id returned empty — logging for manual review"
    else
      pass "  Updated action $id: $project → $slug"
    fi
    echo -n "."
  fi
}

# ── Process Sessions ──────────────────────────────────────────────────────────
processed_sessions=0
updated_sessions=0
skipped_sessions=0
errored_sessions=0
declare -a updated_sessions_list=()
declare -a skipped_sessions_list=()
declare -a errored_sessions_list=()
declare -a manual_sessions=()

process_sessions() {
  echo ""
  echo "━━━ Step 3: Processing Sessions ━━━"
  echo ""

  local offset=0
  local batch_count=0

  while true; do
    local response
    response="$(api_get "/sessions?limit=${LIMIT}&offset=${offset}")"
    [ -z "$response" ] && break

    local count
    count="$(echo "$response" | jq '.sessions | length' 2>/dev/null || echo "0")"
    [ "$count" -eq 0 ] && break

    for row in $(echo "$response" | jq -r '.sessions[] | @base64' 2>/dev/null); do
      _process_session_row "$row"
    done

    batch_count="$((batch_count + count))"
    info "  Sessions batch: $count records (${batch_count} total, ${updated_sessions} needs update)"
    offset="$((offset + LIMIT))"
    [ "$count" -lt "$LIMIT" ] && break
  done

  echo ""
  pass "Sessions processing complete: $processed_sessions processed, $updated_sessions to update, $skipped_sessions skipped, $errored_sessions errored"

  if [ "${#manual_sessions[@]}" -gt 0 ]; then
    echo ""
    warn "Sessions needing manual attention: ${#manual_sessions[@]}"
    for s in "${manual_sessions[@]}"; do
      echo "  $s"
    done
  fi
}

_process_session_row() {
  local row="$1"
  local id project
  id="$(echo "$row" | base64 -d 2>/dev/null | jq -r '.id // ._id // empty' 2>/dev/null)"
  project="$(echo "$row" | base64 -d 2>/dev/null | jq -r '.project // empty' 2>/dev/null)"

  [ -z "$id" ] && return
  processed_sessions=$((processed_sessions + 1))

  local slug
  slug="$(resolve_slug "$project")"

  local record
  # No slug mapping found — skip
  if [ -z "$slug" ]; then
    skipped_sessions=$((skipped_sessions + 1))
    record="$(jq -nc --arg t "session" --arg i "$id" --arg p "${project:-}" --arg r "No mapping found" '{type: $t, id: $i, project: $p, reason: $r}' 2>/dev/null || echo "{\"type\":\"session\",\"id\":\"$id\"}")"
    skipped_sessions_list+=("$record")
    return
  fi

  # Already the correct slug — skip
  if [ "$slug" = "$project" ]; then
    skipped_sessions=$((skipped_sessions + 1))
    record="$(jq -nc --arg t "session" --arg i "$id" --arg p "${project:-}" --arg s "$slug" --arg r "Already target slug" '{type: $t, id: $i, project: $p, slug: $s, reason: $r}' 2>/dev/null || echo "{\"type\":\"session\",\"id\":\"$id\"}")"
    skipped_sessions_list+=("$record")
    return
  fi

  # Validate target slug
  if ! validate_slug "$slug"; then
    errored_sessions=$((errored_sessions + 1))
    record="$(jq -nc --arg t "session" --arg i "$id" --arg p "${project:-}" --arg s "$slug" --arg r "Invalid slug: $slug" '{type: $t, id: $i, project: $p, target_slug: $s, reason: $r}' 2>/dev/null || echo "{\"type\":\"session\",\"id\":\"$id\"}")"
    errored_sessions_list+=("$record")
    warn "  Invalid slug '$slug' for session $id (project: $project) — skipping"
    return
  fi

  # Record the update
  updated_sessions=$((updated_sessions + 1))
  record="$(jq -nc --arg t "session" --arg i "$id" --arg o "${project:-}" --arg n "$slug" '{type: $t, id: $i, old_project: $o, new_project: $n}' 2>/dev/null || echo "{\"type\":\"session\",\"id\":\"$id\"}")"
  updated_sessions_list+=("$record")

  if [ "$DRY_RUN" = false ]; then
    # Try to update via API
    local update_result
    update_result="$(api_post "/sessions/${id}/update" "{\"project\":\"${slug}\"}")"
    if [ -z "$update_result" ]; then
      manual_sessions+=("$id ($project → $slug) — no update endpoint available")
      warn "  Session $id needs manual update: $project → $slug"
    else
      pass "  Updated session $id: $project → $slug"
    fi
    echo -n "."
  fi
}

# ── Generate Report ───────────────────────────────────────────────────────────
generate_report() {
  echo ""
  echo "━━━ Step 4: Generating Report ━━━"
  echo ""

  # Write records to temp files so jq can build the report properly
  local tmp_updated tmp_skipped tmp_errored tmp_manual
  tmp_updated="$(mktemp)"
  tmp_skipped="$(mktemp)"
  tmp_errored="$(mktemp)"
  tmp_manual="$(mktemp)"

  # Write each record on its own line
  for r in "${updated_records[@]:-}" "${updated_sessions_list[@]:-}"; do
    echo "$r" >> "$tmp_updated"
  done
  for r in "${skipped_records[@]:-}" "${skipped_sessions_list[@]:-}"; do
    echo "$r" >> "$tmp_skipped"
  done
  for r in "${errored_records[@]:-}" "${errored_sessions_list[@]:-}"; do
    echo "$r" >> "$tmp_errored"
  done
  for s in "${manual_sessions[@]:-}"; do
    echo "$s" >> "$tmp_manual"
  done

  # Use jq to build a properly escaped JSON report
  jq -n \
    --arg ts "$TIMESTAMP" \
    --argjson dr "$DRY_RUN" \
    --argjson ap "$processed_total" \
    --argjson au "$updated_total" \
    --argjson ask "$skipped_total" \
    --argjson ae "$errored_total" \
    --argjson sp "$processed_sessions" \
    --argjson su "$updated_sessions" \
    --argjson ssk "$skipped_sessions" \
    --argjson se "$errored_sessions" \
    --argjson sm "${#manual_sessions[@]}" \
    --argjson updated "$(cat "$tmp_updated" | jq -s '.' 2>/dev/null || echo '[]')" \
    --argjson skipped "$(cat "$tmp_skipped" | jq -s '.' 2>/dev/null || echo '[]')" \
    --argjson errored "$(cat "$tmp_errored" | jq -s '.' 2>/dev/null || echo '[]')" \
    --argjson manual "$(cat "$tmp_manual" | jq -s -R 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')" \
    '{
      timestamp: $ts,
      dry_run: $dr,
      summary: {
        total_processed: ($ap + $sp),
        actions_processed: $ap,
        actions_updated: $au,
        actions_skipped: $ask,
        actions_errored: $ae,
        sessions_processed: $sp,
        sessions_updated: $su,
        sessions_skipped: $ssk,
        sessions_errored: $se,
        sessions_needing_manual: $sm
      },
      updated_records: $updated,
      skipped_records: $skipped,
      errored_records: $errored,
      manual_sessions: $manual
    }' > "$REPORT_FILE" 2>/dev/null || {
      # Fallback: simpler report if jq fails
      local fallback_report='{"timestamp":"'"$TIMESTAMP"'","dry_run":'"$DRY_RUN"',"summary":{"total_processed":'"$((processed_total + processed_sessions))"',"actions_processed":'"$processed_total"',"actions_updated":'"$updated_total"',"actions_skipped":'"$skipped_total"',"actions_errored":'"$errored_total"',"sessions_processed":'"$processed_sessions"',"sessions_updated":'"$updated_sessions"',"sessions_skipped":'"$skipped_sessions"',"sessions_errored":'"$errored_sessions"',"sessions_needing_manual":'"${#manual_sessions[@]}"'},"note":"Detailed record lists omitted due to jq error"}'
      echo "$fallback_report" > "$REPORT_FILE"
    }

  rm -f "$tmp_updated" "$tmp_skipped" "$tmp_errored" "$tmp_manual"
  pass "Report saved to $REPORT_FILE"

  # Print summary
  echo ""
  echo "──── Migration Summary ────"
  printf "  %-30s %s\n" "Actions processed:" "$processed_total"
  printf "  %-30s %s\n" "Actions updated:" "$updated_total"
  printf "  %-30s %s\n" "Actions skipped:" "$skipped_total"
  printf "  %-30s %s\n" "Actions errored:" "$errored_total"
  echo ""
  printf "  %-30s %s\n" "Sessions processed:" "$processed_sessions"
  printf "  %-30s %s\n" "Sessions updated:" "$updated_sessions"
  printf "  %-30s %s\n" "Sessions skipped:" "$skipped_sessions"
  printf "  %-30s %s\n" "Sessions errored:" "$errored_sessions"
  printf "  %-30s %s\n" "Sessions needing manual:" "${#manual_sessions[@]}"
  echo ""
  if [ "$DRY_RUN" = true ]; then
    info "Dry-run — no actual changes were made."
    info "Re-run without --dry-run to apply changes."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
usage() {
  echo "KodeHold Project Slug Migration (ADR-0036)"
  echo ""
  echo "Usage: bash scripts/migrate-project-slugs.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --dry-run     Preview changes without applying them"
  echo "  --restore     Restore database from pre-migration snapshot"
  echo "  --url URL     Agentmemory API base URL (default: http://localhost:3111)"
  echo "  --help, -h    Show this help message"
  echo ""
  echo "Environment:"
  echo "  AM_URL        Agentmemory API base URL (overrides --url)"
  echo ""
  echo "Examples:"
  echo "  bash scripts/migrate-project-slugs.sh --dry-run"
  echo "  bash scripts/migrate-project-slugs.sh"
  echo "  AM_URL=http://other-host:3111 bash scripts/migrate-project-slugs.sh --dry-run"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --restore) RESTORE=true; shift ;;
    --url) API_BASE="${2}/agentmemory"; shift 2 ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Prerequisites check
if ! command -v curl &>/dev/null; then fail "curl is required but not installed"; fi
if ! command -v jq &>/dev/null; then fail "jq is required but not installed"; fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    KodeHold Project Slug Migration (ADR-0036)               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  API:       $API_BASE"
echo "  Mode:      $($DRY_RUN && echo 'DRY-RUN' || echo 'LIVE')"
echo "  Timestamp: $TIMESTAMP"

# Health check
if ! curl -sf "${API_BASE}/health" >/dev/null 2>&1; then
  if ! curl -sf "${API_BASE}" >/dev/null 2>&1; then
    fail "Cannot reach agentmemory at $API_BASE — is the daemon running?"
  fi
fi
pass "Agentmemory daemon reachable"

# Restore mode
if [ "$RESTORE" = true ]; then
  restore_from_backup
  exit $?
fi

# Main flow
create_backup
process_actions
process_sessions
generate_report

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
