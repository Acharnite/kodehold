#!/usr/bin/env python3
"""Validate config/agents.yaml against config/agents.schema.json.

Checks:
  1. YAML parses correctly
  2. All required fields are present (name, description for each agent)
  3. No duplicate triggers across agents
  4. Validates field values (mode, permission, etc.)

Returns exit code 0 on success, 1 on failure.

Usage:
    python3 scripts/validate_config.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

# Paths
PROJECT_DIR = Path(__file__).resolve().parent.parent
AGENTS_YAML = PROJECT_DIR / "config" / "agents.yaml"
SCHEMA_JSON = PROJECT_DIR / "config" / "agents.schema.json"

VALID_PERMS = {"allow", "deny", "ask"}
VALID_PERM_KEYS = {
    "read", "write", "edit", "glob", "grep",
    "bash", "task", "skill", "webfetch", "websearch",
}
INVALID_MODE_VALUES = ("all", "subagent")  # valid values
EXPECTED_AGENT_COUNT = 9

RED = "\033[0;31m"
GREEN = "\033[0;32m"
NC = "\033[0m"

errors = 0


def error(msg: str) -> None:
    global errors
    print(f"{RED}ERROR:{NC} {msg}", file=sys.stderr)
    errors += 1


def success(msg: str) -> None:
    print(f"{GREEN}OK:{NC} {msg}")


def check(condition: bool, msg: str) -> None:
    if condition:
        success(msg)
    else:
        error(msg)


def main() -> None:
    # Step 1: Check files exist
    if not AGENTS_YAML.is_file():
        error(f"File not found: {AGENTS_YAML}")
    if not SCHEMA_JSON.is_file():
        error(f"File not found: {SCHEMA_JSON}")
    if errors > 0:
        sys.exit(1)

    # Step 2: Parse YAML
    try:
        with open(AGENTS_YAML) as f:
            data = yaml.safe_load(f)
        success("YAML parsed successfully")
    except yaml.YAMLError as e:
        error(f"YAML parse error: {e}")
        sys.exit(1)

    if data is None:
        error("YAML file is empty")
        sys.exit(1)

    # Step 3: Check required top-level keys
    check("agents" in data, "Top-level 'agents' key present")
    if "agents" not in data:
        sys.exit(1)

    agents = data["agents"]
    check(isinstance(agents, list), "'agents' is a list")
    if not isinstance(agents, list):
        sys.exit(1)

    check(len(agents) > 0, "'agents' list is non-empty")
    if not agents:
        sys.exit(1)

    # Step 4: Check all agents have name and description
    for i, agent in enumerate(agents):
        if not isinstance(agent, dict):
            error(f"agents[{i}] is not an object")
            continue
        name_ok = "name" in agent and isinstance(agent["name"], str) and bool(re.match(r'^[a-z][a-z0-9-]*$', agent["name"]))
        check(name_ok, f"agents[{i}].name '{agent.get('name', '')}' is valid slug")

        desc_ok = "description" in agent and isinstance(agent["description"], str)
        check(desc_ok, f"agents[{i}] (name='{agent.get('name', '')}') has description")

    # Step 5: Check agent count
    agent_names = [a.get("name") for a in agents if isinstance(a, dict)]
    check(len(agent_names) == EXPECTED_AGENT_COUNT, f"Expected {EXPECTED_AGENT_COUNT} agents, found {len(agent_names)}: {agent_names}")

    # Step 6: Check for duplicate agent names
    if len(agent_names) != len(set(agent_names)):
        seen = set()
        for name in agent_names:
            if name in seen:
                error(f"Duplicate agent name: '{name}'")
            seen.add(name)

    # Step 7: Check no duplicate triggers across agents
    trigger_map: dict[str, str] = {}
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
                error(f"Duplicate trigger '{t}' across agents: '{trigger_map[t]}' and '{aname}'")
            else:
                trigger_map[t] = aname

    # Step 8: Check defaults
    defaults = data.get("defaults", {})
    if defaults:
        check(isinstance(defaults, dict), "'defaults' is an object")
        if isinstance(defaults, dict):
            # Validate defaults.permission
            dp = defaults.get("permission", {})
            if dp and isinstance(dp, dict):
                for key, val in dp.items():
                    if key == "external_directory":
                        continue
                    check(key in VALID_PERM_KEYS, f"defaults.permission: valid permission key '{key}'")
                    check(val in VALID_PERMS, f"defaults.permission.{key}: valid value '{val}'")
            # Validate defaults.mode
            if "mode" in defaults:
                mode = defaults["mode"]
                check(mode in ("all", "subagent"), f"defaults.mode: valid value '{mode}'")

    # Step 9: Validate each agent's mode, permission, etc.
    for agent in agents:
        if not isinstance(agent, dict):
            continue
        aname = agent.get("name", "unknown")

        # mode validation
        if "mode" in agent:
            mode = agent["mode"]
            check(mode in ("all", "subagent"), f"agent '{aname}'.mode: valid value '{mode}'")

        # permission validation
        perm = agent.get("permission", {})
        if perm and isinstance(perm, dict):
            for key, val in perm.items():
                if key == "external_directory":
                    continue
                check(key in VALID_PERM_KEYS, f"agent '{aname}'.permission: valid key '{key}'")
                check(val in VALID_PERMS, f"agent '{aname}'.permission.{key}: valid value '{val}'")

    if errors > 0:
        print(f"\nValidation FAILED — {errors} error(s) found", file=sys.stderr)
    else:
        print("\nAll validations passed!")

    sys.exit(1 if errors > 0 else 0)


if __name__ == "__main__":
    main()
