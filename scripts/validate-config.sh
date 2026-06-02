#!/usr/bin/env bash
#
# validate-config.sh — Validate config/agents.yaml against config/agents.schema.json
#
# Checks:
#   1. YAML parses correctly
#   2. All required fields are present (name, description for each agent)
#   3. No duplicate triggers across agents
#   4. Validates against JSON Schema
#
# Returns exit code 0 on success, 1 on failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_YAML="$PROJECT_DIR/config/agents.yaml"
SCHEMA_JSON="$PROJECT_DIR/config/agents.schema.json"

export AGENTS_YAML
export SCHEMA_JSON

errors=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
    errors=$((errors + 1))
}

success() {
    echo -e "${GREEN}OK:${NC} $*"
}

# Step 1: Check files exist
if [ ! -f "$AGENTS_YAML" ]; then
    error "File not found: $AGENTS_YAML"
fi
if [ ! -f "$SCHEMA_JSON" ]; then
    error "File not found: $SCHEMA_JSON"
fi
if [ "$errors" -gt 0 ]; then
    exit 1
fi

# Step 2: Validate YAML parsing and schema via Python
python3 << 'PYEOF'
import sys
import os
import yaml
import json
import re

errors = 0

def err(msg):
    global errors
    print(f"ERROR: {msg}", file=sys.stderr)
    errors += 1

# Parse YAML
agents_yaml = os.environ.get("AGENTS_YAML", "")
try:
    with open(agents_yaml) as f:
        data = yaml.safe_load(f)
    print("OK: YAML parsed successfully")
except yaml.YAMLError as e:
    err(f"YAML parse error: {e}")
    sys.exit(1)

if data is None:
    err("YAML file is empty")
    sys.exit(1)

# Check required top-level keys
if "agents" not in data:
    err("Missing required key: 'agents'")
    sys.exit(1)

agents = data["agents"]
if not isinstance(agents, list):
    err("'agents' must be a list")
    sys.exit(1)

if len(agents) == 0:
    err("'agents' list is empty")
    sys.exit(1)

# Check all agents have name and description
for i, agent in enumerate(agents):
    if not isinstance(agent, dict):
        err(f"agents[{i}] is not an object")
        continue
    if "name" not in agent:
        err(f"agents[{i}] missing required field: 'name'")
    elif not isinstance(agent["name"], str) or not re.match(r'^[a-z][a-z0-9-]*$', agent["name"]):
        err(f"agents[{i}].name '{agent.get('name', '')}' must match pattern ^[a-z][a-z0-9-]*$")
    if "description" not in agent:
        err(f"agents[{i}] (name='{agent.get('name', '')}') missing required field: 'description'")
    elif not isinstance(agent["description"], str):
        err(f"agents[{i}].description must be a string")

# Check agent count
agent_names = [a.get("name") for a in agents if isinstance(a, dict)]
expected_count = 8
if len(agent_names) != expected_count:
    err(f"Expected {expected_count} agents, found {len(agent_names)}: {agent_names}")

# Check for duplicate agent names
if len(agent_names) != len(set(agent_names)):
    seen = set()
    for name in agent_names:
        if name in seen:
            err(f"Duplicate agent name: '{name}'")
        seen.add(name)

# Check no duplicate triggers across agents
trigger_map = {}  # trigger -> agent_name
for agent in agents:
    if not isinstance(agent, dict):
        continue
    aname = agent.get("name", "unknown")
    triggers = agent.get("triggers", [])
    if not isinstance(triggers, list):
        continue
    for trigger in triggers:
        if not isinstance(trigger, str):
            continue
        t = trigger.strip()
        if t in trigger_map:
            err(f"Duplicate trigger '{t}' across agents: '{trigger_map[t]}' and '{aname}'")
        else:
            trigger_map[t] = aname

# Check defaults if present
defaults = data.get("defaults", {})
if defaults:
    if not isinstance(defaults, dict):
        err("'defaults' must be an object")
    else:
        # Validate defaults.permission if present
        dp = defaults.get("permission", {})
        if dp and isinstance(dp, dict):
            valid_perms = {"allow", "deny", "ask"}
            for key, val in dp.items():
                if key == "external_directory":
                    continue
                if key not in ["read", "write", "edit", "glob", "grep", "bash", "task", "skill", "webfetch", "websearch"]:
                    err(f"defaults.permission: unknown permission key '{key}'")
                if val not in valid_perms:
                    err(f"defaults.permission.{key}: invalid value '{val}', must be one of {valid_perms}")
        # Validate defaults.mode if present
        if "mode" in defaults:
            mode = defaults["mode"]
            if mode not in ("all", "subagent"):
                err(f"defaults.mode: invalid value '{mode}', must be 'all' or 'subagent'")

# Validate each agent's mode, permission values, etc.
valid_perms = {"allow", "deny", "ask"}
for agent in agents:
    if not isinstance(agent, dict):
        continue
    aname = agent.get("name", "unknown")
    # mode validation
    if "mode" in agent:
        mode = agent["mode"]
        if mode not in ("all", "subagent"):
            err(f"agent '{aname}'.mode: invalid value '{mode}', must be 'all' or 'subagent'")
    # permission validation
    perm = agent.get("permission", {})
    if perm and isinstance(perm, dict):
        for key, val in perm.items():
            if key == "external_directory":
                continue
            if key not in ["read", "write", "edit", "glob", "grep", "bash", "task", "skill", "webfetch", "websearch"]:
                err(f"agent '{aname}'.permission: unknown permission key '{key}'")
            if val not in valid_perms:
                err(f"agent '{aname}'.permission.{key}: invalid value '{val}', must be one of {valid_perms}")

if errors > 0:
    print(f"\nValidation FAILED — {errors} error(s) found", file=sys.stderr)
else:
    print("\nAll validations passed!")

sys.exit(1 if errors > 0 else 0)
PYEOF

exit_code=$?
exit $exit_code
