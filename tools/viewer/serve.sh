#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR" || exit 1
if [ -f /tmp/kodehold-viewer.pid ] && kill -0 "$(cat /tmp/kodehold-viewer.pid)" 2>/dev/null; then
  echo "KodeHold viewer already running (pid $(cat /tmp/kodehold-viewer.pid))"
  exit 0
fi
setsid node serve.mjs > /tmp/kodehold-viewer.log 2>&1 &
PID=$!
echo $PID > /tmp/kodehold-viewer.pid
sleep 1
if kill -0 "$PID" 2>/dev/null; then
  echo "KodeHold viewer started on http://0.0.0.0:3115 (pid $PID)"
else
  echo "KodeHold viewer failed to start. Check /tmp/kodehold-viewer.log"
  exit 1
fi
