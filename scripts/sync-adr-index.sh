#!/usr/bin/env bash
# sync-adr-index.sh — generate tools/viewer/adr-index.json from ADR YAML frontmatter
#
# Scans both root docs/adr/ and workspaces/*/docs/adr/.
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

  # Collect all ADR files from root + workspaces
  ADR_FILES=()
  for f in docs/adr/ADR-*.md; do
    [[ "$(basename "$f")" == *.original.md ]] && continue
    ADR_FILES+=("kodehold:$f")
  done
  for f in workspaces/*/docs/adr/ADR-*.md; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == *.original.md ]] && continue
    ws=$(echo "$f" | cut -d/ -f2)
    ADR_FILES+=("$ws:$f")
  done

  for entry in "${ADR_FILES[@]}"; do
    project="${entry%%:*}"
    f="${entry#*:}"

    $FIRST || echo ',' >> "$OUTPUT"
    FIRST=false

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

    mtime=$(stat -c %Y "$f" 2>/dev/null || echo "0")

    cat >> "$OUTPUT" << ENTRY
    {
      "id": "$id",
      "title": $(echo "$title" | jq -R -s '.'),
      "status": "$status",
      "project": "$project",
      "mtime": $mtime,
      "phase": $phase_json
    }
ENTRY
  done

  echo '  ]' >> "$OUTPUT"
  echo '}' >> "$OUTPUT"

  echo "Written: $OUTPUT ($(jq '.adrs | length' "$OUTPUT") ADRs across $(jq '[.adrs[].project] | unique | length' "$OUTPUT") projects)"
  exit 0
fi

# ── Fallback: Python implementation ────────────────────────────────────────
if command -v python3 &> /dev/null; then
  exec python3 - "$@" << 'PYEOF'
import json, re, sys, yaml
from datetime import datetime, timezone
from pathlib import Path

OUTPUT = Path("tools/viewer/adr-index.json")

adrs = []

def scan_adrs(adr_dir, project):
    """Scan a directory for ADR-*.md files and return parsed entries."""
    results = []
    if not adr_dir.exists():
        return results
    for f in sorted(adr_dir.glob("ADR-*.md")):
        if f.name.endswith('.original.md'):
            continue

        text = f.read_text()
        m = re.match(r'^---\n(.*?)\n---', text, re.DOTALL)
        try:
            frontmatter = yaml.safe_load(m.group(1)) if m else {}
        except yaml.YAMLError:
            frontmatter = {}

        # Try frontmatter id first, fall back to filename extraction
        adr_id = frontmatter.get("id") if frontmatter else None
        if not adr_id:
            id_match = re.match(r'(ADR-\d{4}[a-z]*)', f.stem)
            adr_id = id_match.group(1) if id_match else f.stem

        title_match = re.search(r'^# (.+)$', text, re.MULTILINE)
        status_match = re.search(r'^(Proposed|Accepted|Deprecated|Superseded)$', text, re.MULTILINE)

        phase = frontmatter.get("phase")
        if not phase:
            phase = {"current": 0, "total": 1, "status": {"1": "done"}}

        results.append({
            "id": adr_id,
            "title": title_match.group(1) if title_match else f.stem,
            "status": status_match.group(1) if status_match else "Proposed",
            "project": project,
            "mtime": int(f.stat().st_mtime),
            "phase": phase
        })
    return results

# Scan root project
adrs.extend(scan_adrs(Path("docs/adr"), "kodehold"))

# Scan workspace projects
for ws_dir in sorted(Path("workspaces").iterdir()):
    if ws_dir.is_dir():
        adrs.extend(scan_adrs(ws_dir / "docs" / "adr", ws_dir.name))

output_json = {
    "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "adrs": adrs
}
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(output_json, indent=2))

projects = set(a["project"] for a in adrs)
print(f"Written: {OUTPUT} ({len(adrs)} ADRs across {len(projects)} projects)")
PYEOF
fi

echo "ERROR: Requires either yq+jq or python3 (with PyYAML)" >&2
exit 1
