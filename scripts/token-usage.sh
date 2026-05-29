#!/usr/bin/env bash
# Token usage per agent for the current KodeHold project.
# Queries OpenCode's SQLite database for aggregated token counts.
# Usage: token-usage.sh [--project <name>] [--minutes <N>]
# Defaults to project "kodehold" and last 60 minutes.

set -euo pipefail

# Default values
PROJECT="kodehold"
MINUTES=60
DB_PATH="$HOME/.local/share/opencode/opencode.db"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --minutes)
      MINUTES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate DB exists
if [[ ! -f "$DB_PATH" ]]; then
  echo "OpenCode database not found at $DB_PATH" >&2
  exit 1
fi

# Calculate cutoff timestamp (seconds since epoch)
CUTOFF=$(date -d "-${MINUTES} minutes" +%s 2>/dev/null || date -v-${MINUTES}M +%s 2>/dev/null)

# Sanitize PROJECT to prevent SQL injection
PROJECT=$(echo "$PROJECT" | tr -cd '[:alnum:]-')

# Query token usage per agent for the project within the time window
sqlite3 -json "$DB_PATH" <<EOF
SELECT
  s.agent,
  SUM(s.tokens_input) AS tokens_input,
  SUM(s.tokens_output) AS tokens_output,
  SUM(s.tokens_input + s.tokens_output) AS total_tokens,
  COUNT(*) AS session_count
FROM session s
JOIN project p ON s.project_id = p.id
WHERE p.worktree LIKE '%${PROJECT}%'
  AND s.time_created >= ${CUTOFF}
  AND s.agent IS NOT NULL
GROUP BY s.agent
ORDER BY total_tokens DESC;
EOF