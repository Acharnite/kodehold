#!/usr/bin/env bash
if [ -f /tmp/kodehold-viewer.pid ]; then
  kill "$(cat /tmp/kodehold-viewer.pid)" 2>/dev/null
  rm /tmp/kodehold-viewer.pid
  echo "KodeHold viewer stopped"
else
  echo "No running KodeHold viewer found"
fi
