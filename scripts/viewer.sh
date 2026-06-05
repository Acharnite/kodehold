#!/usr/bin/env bash
# viewer.sh — start/stop/restart KodeHold custom viewer
set -euo pipefail

PIDFILE="/tmp/kodehold-viewer.pid"
LOGFILE="/tmp/viewer.log"
PORT=3115

case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Viewer already running (PID $(cat "$PIDFILE"))"
      exit 0
    fi
    cd /home/kiffer/project/kodehold
    nohup node tools/viewer/serve.mjs > "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 1
    if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Viewer started on http://0.0.0.0:${PORT} (PID $(cat "$PIDFILE"))"
    else
      echo "ERROR: Viewer failed to start"
      cat "$LOGFILE"
      exit 1
    fi
    ;;
  stop)
    if [ ! -f "$PIDFILE" ]; then
      echo "No PID file found, trying pkill..."
      pkill -f "serve.mjs" 2>/dev/null || echo "No viewer process found"
    else
      kill "$(cat "$PIDFILE")" 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "Viewer stopped"
    fi
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Viewer running (PID $(cat "$PIDFILE")) — http://0.0.0.0:${PORT}"
    else
      echo "Viewer not running"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
