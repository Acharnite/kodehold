#!/usr/bin/env bash
# agentmemory-session-cleanup.sh
# Auto-close stale active sessions in agentmemory
set -euo pipefail

DRY_RUN=true
IDLE_MIN=60
URL="http://localhost:3111"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute) DRY_RUN=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --idle) IDLE_MIN="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--execute] [--dry-run] [--idle MIN] [--url URL]"
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if ! command -v curl &>/dev/null; then echo "ERROR: curl required"; exit 1; fi

echo "=== agentmemory session cleanup ==="
echo "  URL:       $URL"
echo "  Idle min:  $IDLE_MIN min"
echo "  Mode:      $($DRY_RUN && echo 'DRY-RUN' || echo 'LIVE')"
echo ""

# Export env vars for the Python engine
export IDLE_MIN
export DRY_RUN="$DRY_RUN"
export AM_URL="$URL"
if ! curl -s "${URL}/agentmemory/sessions" >/dev/null 2>&1; then
  echo "ERROR: Cannot reach agentmemory at $URL"
  exit 1
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "${DIR}/agentmemory-session-cleanup.py"
