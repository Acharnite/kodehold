#!/usr/bin/env bash
# sync-adr-index.sh — generate tools/viewer/adr-index.json from ADR YAML frontmatter
#
# Uses bash+yq as primary implementation. Falls back to Python3 if yq is not
# available. Requires either (yq + jq) or python3 (with PyYAML).
set -euo pipefail

# ── Primary: bash + yq implementation ──────────────────────────────────────
if command -v yq &> /dev/null && command -v jq &> /dev/null; then
  OUTPUT="tools/viewer/adr-index.json"
  mkdir -p "$(dirname "$OUTPUT")"

  echo '{' > "$OUTPUT"
  echo '  "updatedAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",' >> "$OUTPUT"
  echo '  "adrs": [' >> "$OUTPUT"

  FIRST=true
  for f in docs/adr/ADR-*.md; do
    # Skip .original.md backup files created by memory_compress_file
    [[ "$(basename "$f")" == *.original.md ]] && continue

    $FIRST || echo ',' >> "$OUTPUT"
    FIRST=false
    # Try frontmatter id first, fall back to filename extraction

    # Try frontmatter id first, fall back to filename extraction
    fm_id=$(sed -n '/^---$/,/^---$/p' "$f" | sed '1d;$d' | yq eval '.id // ""' - 2>/dev/null || echo "")
    if [ -n "$fm_id" ]; then
      id="$fm_id"
    else
      id=$(basename "$f" | sed 's/\.md$//' | sed 's/^\(ADR-[0-9]\{4\}\).*/\1/')
    fi
    title=$(sed -n 's/^# //p' "$f" | head -1)
    status=$(sed -n '/^## Status/,/^## /p' "$f" | grep -E '^(Proposed|Accepted|Deprecated|Superseded)$' | head -1)

    # Parse YAML frontmatter for phase block via yq
    phase_json=$(sed -n '/^---$/,/^---$/p' "$f" | sed '1d;$d' | yq eval '.phase' - 2>/dev/null || echo "null")

    if [ "$phase_json" = "null" ] || [ -z "$phase_json" ]; then
      phase_json='{"current":0,"total":1,"status":{"1":"done"}}'
    fi

    cat >> "$OUTPUT" << ENTRY
    {
      "id": "$id",
      "title": $(echo "$title" | jq -R -s '.'),
      "status": "$status",
      "phase": $phase_json
    }
ENTRY
  done

  echo '  ]' >> "$OUTPUT"
  echo '}' >> "$OUTPUT"

  echo "Written: $OUTPUT ($(jq '.adrs | length' "$OUTPUT") ADRs)"
  exit 0
fi

# ── Fallback: Python implementation ────────────────────────────────────────
if command -v python3 &> /dev/null; then
  exec python3 - "$@" << 'PYEOF'
import json, re, sys, yaml
from datetime import datetime, timezone
from pathlib import Path

ADRS_DIR = Path("docs/adr")
OUTPUT = Path("tools/viewer/adr-index.json")

adrs = []
for f in sorted(ADRS_DIR.glob("ADR-*.md")):
    if f.name.endswith('.original.md'):
        continue

    text = f.read_text()
    m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
    try:
        frontmatter = yaml.safe_load(m.group(1)) if m else {}
    except yaml.YAMLError:
        frontmatter = {}

    # Try frontmatter id first, fall back to filename extraction
    id = frontmatter.get("id") if frontmatter else None
    if not id:
        id_match = re.match(r'(ADR-\d{4}[a-z]*)', f.stem)
        id = id_match.group(1) if id_match else f.stem
    title_match = re.search(r'^# (.+)$', text, re.MULTILINE)
    status_match = re.search(r'^(Proposed|Accepted|Deprecated|Superseded)$', text, re.MULTILINE)

    phase = frontmatter.get("phase")
    if not phase:
        phase = {"current": 0, "total": 1, "status": {"1": "done"}}

    adrs.append({
        "id": id,
        "title": title_match.group(1) if title_match else f.stem,
        "status": status_match.group(1) if status_match else "Proposed",
        "phase": phase
    })

output_json = {"updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "adrs": adrs}
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(output_json, indent=2))
print(f"Written: {OUTPUT} ({len(adrs)} ADRs)")
PYEOF
fi

echo "ERROR: Requires either yq+jq or python3 (with PyYAML)" >&2
exit 1
