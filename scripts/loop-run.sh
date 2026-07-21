#!/bin/bash
# scripts/loop-run.sh — Wrapper for scheduled opencode loops
# Usage: scripts/loop-run.sh <loop-name> "<prompt>"

LOOP_NAME="$1"
PROMPT="$2"
START_TIME=$(date -Iseconds)
EXIT_CODE=0

echo "## $LOOP_NAME — $START_TIME" >> loop-run-log.md
opencode run "$PROMPT" 2>&1 | tee -a loop-run-log.md
EXIT_CODE=${PIPESTATUS[0]}

DURATION=$(( $(date +%s) - $(date -d "$START_TIME" +%s) ))
echo "**Exit code:** $EXIT_CODE | **Duration:** ${DURATION}s" >> loop-run-log.md
echo "" >> loop-run-log.md

if [ $EXIT_CODE -ne 0 ]; then
    touch .loop_error
    echo "**⚠️ Non-zero exit — .loop_error marker created for FLS triage**" >> loop-run-log.md
fi

exit $EXIT_CODE
