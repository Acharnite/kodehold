#!/usr/bin/env bash
#
# sync-agent-config.sh — Sync YAML frontmatter between config/agents.yaml and .opencode/agents/*.md
#
# This script syncs machine configuration fields from config/agents.yaml (source of truth)
# into the YAML frontmatter of .opencode/agents/*.md files.
#
# Conflict resolution: YAML values win when both sources define the same field.
#
# Modes:
#   default       Write changes to .md frontmatter (YAML -> .md)
#   --dry-run     Show what would change without modifying files
#   --diff        Report-only mode. Exit 1 if any mismatches found.
#
# Trigger extraction: Removes "Triggers: ..." suffixes from description fields
#                     since triggers are now a first-class YAML field.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_YAML="$PROJECT_DIR/config/agents.yaml"
AGENTS_DIR="$PROJECT_DIR/.opencode/agents"

DRY_RUN=false
DIFF_MODE=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --diff)    DIFF_MODE=true ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--diff]"
            echo ""
            echo "  --dry-run   Show what would change without modifying files"
            echo "  --diff      Report-only mode. Exit 1 if mismatches found."
            exit 0
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

error() { echo -e "${RED}ERROR:${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}WARN:${NC} $*"; }
info()  { echo -e "${GREEN}INFO:${NC} $*"; }

# Fields to sync from YAML to .md frontmatter
SYNC_FIELDS=("name" "description" "mode" "hidden" "model" "permission")

mismatches=0

# Check files exist
if [ ! -f "$AGENTS_YAML" ]; then
    error "File not found: $AGENTS_YAML"
    exit 1
fi
if [ ! -d "$AGENTS_DIR" ]; then
    error "Directory not found: $AGENTS_DIR"
    exit 1
fi

# Export paths for Python heredoc
export AGENTS_YAML
export AGENTS_DIR
export DRY_RUN
export DIFF_MODE

# Run Python sync logic
# NOTE: quoted 'PYEOF' prevents bash from expanding backticks and $()
python3 << 'PYEOF'
import sys
import yaml
import re
import os

dry_run = os.environ.get('DRY_RUN', 'false').lower() in ('true', '1')
diff_mode = os.environ.get('DIFF_MODE', 'false').lower() in ('true', '1')

# Fields to sync
SYNC_FIELDS = ["name", "description", "mode", "hidden", "model", "permission"]

agents_yaml = os.environ.get('AGENTS_YAML', 'config/agents.yaml')
agents_dir = os.environ.get('AGENTS_DIR', '.opencode/agents')

try:
    with open(agents_yaml) as f:
        config = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"ERROR: YAML parse error: {e}", file=sys.stderr)
    sys.exit(1)

if config is None or "agents" not in config:
    print("ERROR: No agents found in YAML config", file=sys.stderr)
    sys.exit(1)

agents = config["agents"]

# Build agent lookup
agent_map = {}
for agent in agents:
    if isinstance(agent, dict) and "name" in agent:
        agent_map[agent["name"]] = agent

mismatches = 0

# Process each .md file
for fname in sorted(os.listdir(agents_dir)):
    if not fname.endswith(".md"):
        continue

    fpath = os.path.join(agents_dir, fname)
    agent_name = fname.replace(".md", "")

    if agent_name not in agent_map:
        print(f"WARN: Agent '{agent_name}' has .md file but no entry in config/agents.yaml")
        continue

    yaml_agent = agent_map[agent_name]

    with open(fpath) as f:
        content = f.read()

    # Check for YAML frontmatter
    fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n(.*)', content, re.DOTALL)
    if not fm_match:
        print(f"WARN: No frontmatter found in {fpath}")
        continue

    fm_text = fm_match.group(1)
    body = fm_match.group(2)

    # Parse existing frontmatter
    try:
        existing_fm = yaml.safe_load(fm_text) or {}
    except yaml.YAMLError as e:
        print(f"ERROR: Cannot parse frontmatter in {fname}: {e}", file=sys.stderr)
        continue

    # Build new frontmatter: YAML values win
    new_fm = {}

    # Start with existing frontmatter fields (preserve non-synced fields)
    for k, v in existing_fm.items():
        if k not in SYNC_FIELDS:
            new_fm[k] = v

    # Apply YAML config values (these win)
    for field in SYNC_FIELDS:
        if field == "permission":
            # Merge permission dicts per-key: start with .md baseline, overlay YAML overrides
            merged_perm = {}
            existing_perm = existing_fm.get("permission", {})
            if isinstance(existing_perm, dict):
                merged_perm.update(existing_perm)
            yaml_perm = yaml_agent.get("permission", {})
            if isinstance(yaml_perm, dict):
                merged_perm.update(yaml_perm)
            if merged_perm:
                new_fm["permission"] = merged_perm
            elif "permission" in existing_fm:
                new_fm["permission"] = existing_fm["permission"]
        elif field in yaml_agent:
            new_fm[field] = yaml_agent[field]
        elif field in existing_fm:
            new_fm[field] = existing_fm[field]

    # Check for trigger extraction from description
    description = new_fm.get("description", "")
    if description and isinstance(description, str):
        trigger_match = re.search(r'\n\s*Triggers:\s*.*$', description)
        if trigger_match:
            new_desc = description[:trigger_match.start()]
            new_fm["description"] = new_desc.strip()

    # Helper: compare effective new_fm against existing_fm
    if diff_mode or dry_run:
        for field in SYNC_FIELDS:
            new_val = new_fm.get(field)
            existing_val = existing_fm.get(field)

            if new_val == existing_val:
                continue

            # For description, clean Triggers: suffix from both before comparing
            if field == "description":
                new_desc = str(new_val) if new_val else ""
                existing_desc = str(existing_val) if existing_val else ""
                new_clean = re.sub(r'\n\s*Triggers:\s*.*$', '', new_desc).strip()
                existing_clean = re.sub(r'\n\s*Triggers:\s*.*$', '', existing_desc).strip()
                if new_clean == existing_clean:
                    continue  # Only difference is Triggers: suffix — will be cleaned

            if diff_mode:
                mismatches += 1
                prefix = "DIFF"
            else:
                prefix = "WOULD CHANGE"

            new_str = str(new_val) if new_val else "(empty)"
            existing_str = str(existing_val) if existing_val else "(empty)"
            if len(new_str) > 80:
                new_str = new_str[:77] + "..."
            if len(existing_str) > 80:
                existing_str = existing_str[:77] + "..."
            print(f"{prefix}: {agent_name}.{field}")
            print(f"  YAML ->: {new_str}")
            print(f"  .md:     {existing_str}")

        # Check for triggers in description that should be extracted
        yaml_triggers = yaml_agent.get("triggers", [])
        if not yaml_triggers and existing_fm.get("description"):
            desc = existing_fm.get("description", "")
            trig_match = re.search(r'Triggers:\s*(.*)', desc)
            if trig_match:
                print(f"INFO: {agent_name} has Triggers in description but not in YAML triggers field")

        if diff_mode:
            continue
        else:
            # dry-run — done with this agent
            continue

    # Build new YAML frontmatter text
    lines = []

    def yaml_quote_key(k):
        """Quote a YAML key if it contains characters special to YAML."""
        if not k:
            return '""'
        if k[0] in ('*', '&', '!', '|', '>', '%', '@', '`'):
            return f'"{k}"'
        if ': ' in k or '# ' in k:
            return f'"{k}"'
        if k[0] == '?' or k[0] == '-':
            return f'"{k}"'
        return k

    def yaml_quote_val(sv):
        """Quote a YAML scalar value if needed."""
        if not sv:
            return '""'
        if sv[0] in ('*', '&', '!', '|', '>', '%', '@', '`'):
            return f'"{sv}"'
        if ': ' in sv or '# ' in sv:
            return f'"{sv}"'
        if sv[0] == '-' or sv[0] == '?':
            return f'"{sv}"'
        # Only safe plain characters
        return sv

    def serialize_yaml(k, v, indent=0):
        """Serialize a YAML key-value pair at given indent level."""
        pfx = "  " * indent
        safe_k = yaml_quote_key(str(k))
        if v is None:
            return []
        if isinstance(v, bool):
            return [f"{pfx}{safe_k}: {str(v).lower()}"]
        if isinstance(v, dict):
            result = [f"{pfx}{safe_k}:"]
            for sk, sv in v.items():
                result.extend(serialize_yaml(sk, sv, indent + 1))
            return result
        if isinstance(v, list):
            if not v:
                return []
            result = [f"{pfx}{safe_k}:"]
            for item in v:
                result.append(f"{pfx}  - {item}")
            return result
        # scalar (string, int, etc.)
        sv = str(v)
        if "\n" in sv:
            result = [f"{pfx}{safe_k}: |"]
            for line in sv.split("\n"):
                result.append(f"{pfx}  {line}")
            return result
        safe_v = yaml_quote_val(sv)
        return [f"{pfx}{safe_k}: {safe_v}"]

    for k, v in new_fm.items():
        lines.extend(serialize_yaml(k, v, indent=0))

    new_fm_text = "\n".join(lines)
    new_content = f"---\n{new_fm_text}\n---\n{body}"

    if new_content != content:
        print(f"UPDATED: {fname}")
        with open(fpath, 'w') as f:
            f.write(new_content)
    else:
        print(f"UNCHANGED: {fname}")

if diff_mode:
    print(f"\nDiff complete. Mismatches found: {mismatches}")
    sys.exit(1 if mismatches > 0 else 0)
elif dry_run:
    print(f"\nDry-run complete. No files modified.")
else:
    print(f"\nSync complete.")
PYEOF
