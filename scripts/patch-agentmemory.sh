#!/usr/bin/env bash
# scripts/patch-agentmemory.sh
#
# Patches agentmemory viewer server to bind to 0.0.0.0 (all interfaces)
# instead of 127.0.0.1 (loopback only), making the WebSocket viewer
# on port 3113 accessible via LAN IPs.
#
# Reference: docs/notes/agentmemory-port3113-hotfix.md
# Patch file: patches/agentmemory-viewer-bind.patch
#
# CRITICAL — src-B8J9Exum.mjs is the REAL runtime file:
#   cli.mjs imports src-B8J9Exum.mjs, NOT index.mjs.
#   index.mjs is dead code. BOTH files must be patched with identical
#   changes, or just src-B8J9Exum.mjs. This script correctly patches both.
#
# For ALL patches (viewer-bind, triggerVoid, summary-XML-parse, etc.):
#   sudo bash patches/agentmemory-merged.patch
#
# Run after: npm install -g @agentmemory/agentmemory (upgrade overwrites patch)

set -euo pipefail

FILES=(
  "/usr/local/lib/node_modules/@agentmemory/agentmemory/dist/index.mjs"
  "/usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-B8J9Exum.mjs"
)

PATCHED=0
SKIPPED=0
MISSING=0

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "✗ File not found: $f"
    MISSING=$((MISSING + 1))
    continue
  fi

  if grep -q 'server.listen(currentPort, "127.0.0.1")' "$f" 2>/dev/null; then
    sed -i 's/server.listen(currentPort, "127.0.0.1");/server.listen(currentPort, "0.0.0.0");/' "$f"
    echo "✓ Patched: $f"
    PATCHED=$((PATCHED + 1))
  elif grep -q 'server.listen(currentPort, "0.0.0.0")' "$f" 2>/dev/null; then
    echo "✓ Already patched: $f"
    SKIPPED=$((SKIPPED + 1))
  else
    echo "⚠  Unexpected file content (version mismatch?): $f"
    MISSING=$((MISSING + 1))
  fi
done

echo ""
echo "--- Summary ---"
echo "Patched:  $PATCHED"
echo "Skipped:  $SKIPPED (already patched)"
echo "Issues:   $MISSING (not found / version mismatch)"

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "⚠  agentmemory version may have changed. Check in:"
  echo "   npm list -g @agentmemory/agentmemory"
  echo "   Then update patches/agentmemory-viewer-bind.patch accordingly."
  exit 1
fi

if [ "$PATCHED" -gt 0 ]; then
  echo ""
  echo "🔄 Restart agentmemory to apply changes:"
  echo "   systemctl --user restart agentmemory"
fi
