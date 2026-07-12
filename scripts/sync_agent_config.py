#!/usr/bin/env python3
"""Sync YAML frontmatter between config/agents.yaml and .opencode/agents/*.md.

This script syncs machine configuration fields from config/agents.yaml (source of truth)
into the YAML frontmatter of .opencode/agents/*.md files.

Conflict resolution: YAML values win when both sources define the same field.

Modes:
  default       Write changes to .md frontmatter (YAML -> .md)
  --dry-run     Show what would change without modifying files
  --diff        Report-only mode. Exit 1 if any mismatches found.

Trigger extraction: Removes "Triggers: ..." suffixes from description fields
                    since triggers are now a first-class YAML field.

Usage:
    python3 scripts/sync_agent_config.py
    python3 scripts/sync_agent_config.py --dry-run
    python3 scripts/sync_agent_config.py --diff
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Any

import yaml

PROJECT_DIR = Path(__file__).resolve().parent.parent
AGENTS_YAML = PROJECT_DIR / "config" / "agents.yaml"
AGENTS_DIR = PROJECT_DIR / ".opencode" / "agents"

# Fields to sync from YAML to .md frontmatter
SYNC_FIELDS = ["name", "description", "mode", "hidden", "model", "permission"]

RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
NC = "\033[0m"


def error(msg: str) -> None:
    print(f"{RED}ERROR:{NC} {msg}", file=sys.stderr)


def warn(msg: str) -> None:
    print(f"{YELLOW}WARN:{NC} {msg}")


def info(msg: str) -> None:
    print(f"{GREEN}INFO:{NC} {msg}")


def yaml_quote_key(k: str) -> str:
    """Quote a YAML key if it contains characters special to YAML."""
    if not k:
        return '""'
    if k[0] in ('*', '&', '!', '|', '>', '%', '@', '`') or ': ' in k or '# ' in k:
        return f'"{k}"'
    return k


def yaml_quote_val(sv: str) -> str:
    """Quote a YAML scalar value if needed."""
    if not sv:
        return '""'
    if sv[0] in ('*', '&', '!', '|', '>', '%', '@', '`') or ': ' in sv or '# ' in sv:
        return f'"{sv}"'
    return sv


def serialize_yaml(k: str, v: Any, indent: int = 0) -> list[str]:
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
    # scalar
    sv = str(v)
    if "\n" in sv:
        result = [f"{pfx}{safe_k}: |"]
        for line in sv.split("\n"):
            result.append(f"{pfx}  {line}")
        return result
    safe_v = yaml_quote_val(sv)
    return [f"{pfx}{safe_k}: {safe_v}"]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sync YAML frontmatter between config/agents.yaml and .opencode/agents/*.md"
    )
    parser.add_argument("--dry-run", action="store_true", help="Show what would change without modifying files")
    parser.add_argument("--diff", action="store_true", help="Report-only mode. Exit 1 if mismatches found.")
    args = parser.parse_args()

    # Check files exist
    if not AGENTS_YAML.is_file():
        error(f"File not found: {AGENTS_YAML}")
        sys.exit(1)
    if not AGENTS_DIR.is_dir():
        error(f"Directory not found: {AGENTS_DIR}")
        sys.exit(1)

    # Parse YAML
    try:
        with open(AGENTS_YAML) as f:
            config = yaml.safe_load(f)
    except yaml.YAMLError as e:
        error(f"YAML parse error: {e}")
        sys.exit(1)

    if not config or "agents" not in config:
        error("No agents found in YAML config")
        sys.exit(1)

    # Build agent lookup
    agent_map: dict[str, dict] = {}
    for agent in config["agents"]:
        if isinstance(agent, dict) and "name" in agent:
            agent_map[agent["name"]] = agent

    mismatches = 0
    updated_count = 0
    unchanged_count = 0

    # Process each .md file
    for fname in sorted(os.listdir(str(AGENTS_DIR))):
        if not fname.endswith(".md"):
            continue

        fpath = AGENTS_DIR / fname
        agent_name = fname.replace(".md", "")

        if agent_name not in agent_map:
            warn(f"Agent '{agent_name}' has .md file but no entry in config/agents.yaml")
            continue

        yaml_agent = agent_map[agent_name]
        content = fpath.read_text()

        # Check for YAML frontmatter
        fm_match = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)", content, re.DOTALL)
        if not fm_match:
            warn(f"No frontmatter found in {fpath}")
            continue

        fm_text = fm_match.group(1)
        body = fm_match.group(2)

        # Parse existing frontmatter
        try:
            existing_fm = yaml.safe_load(fm_text) or {}
        except yaml.YAMLError as e:
            error(f"Cannot parse frontmatter in {fname}: {e}")
            continue

        # Build new frontmatter: YAML values win
        new_fm: dict = {}

        # Preserve non-synced fields
        for k, v in existing_fm.items():
            if k not in SYNC_FIELDS:
                new_fm[k] = v

        # Apply YAML config values
        for field in SYNC_FIELDS:
            if field == "permission":
                # Merge permission dicts per-key
                merged_perm: dict = {}
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

        # Clean Triggers: suffix from description
        description = new_fm.get("description", "")
        if description and isinstance(description, str):
            trigger_match = re.search(r"\n\s*Triggers:\s*.*$", description)
            if trigger_match:
                new_fm["description"] = description[: trigger_match.start()].strip()

        # Diff / dry-run mode
        if args.diff or args.dry_run:
            for field in SYNC_FIELDS:
                new_val = new_fm.get(field)
                existing_val = existing_fm.get(field)

                if new_val == existing_val:
                    continue

                # For description, clean Triggers before comparing
                if field == "description":
                    new_desc = str(new_val) if new_val else ""
                    existing_desc = str(existing_val) if existing_val else ""
                    new_clean = re.sub(r"\n\s*Triggers:\s*.*$", "", new_desc).strip()
                    existing_clean = re.sub(r"\n\s*Triggers:\s*.*$", "", existing_desc).strip()
                    if new_clean == existing_clean:
                        continue

                if args.diff:
                    mismatches += 1
                    prefix = "DIFF"
                else:
                    prefix = "WOULD CHANGE"

                new_str = str(new_val)[:77] + "..." if new_val and len(str(new_val)) > 80 else str(new_val or "(empty)")
                existing_str = str(existing_val)[:77] + "..." if existing_val and len(str(existing_val)) > 80 else str(existing_val or "(empty)")
                print(f"{prefix}: {agent_name}.{field}")
                print(f"  YAML ->: {new_str}")
                print(f"  .md:     {existing_str}")

            # Check for triggers in description that should be extracted
            yaml_triggers = yaml_agent.get("triggers", [])
            if not yaml_triggers and existing_fm.get("description"):
                desc = str(existing_fm.get("description", ""))
                trig_match = re.search(r"Triggers:\s*(.*)", desc)
                if trig_match:
                    print(f"INFO: {agent_name} has Triggers in description but not in YAML triggers field")

            if args.diff:
                continue
            else:
                continue  # dry-run — done with this agent

        # Build new YAML frontmatter text
        lines: list[str] = []
        for k, v in new_fm.items():
            lines.extend(serialize_yaml(k, v))

        new_fm_text = "\n".join(lines)
        new_content = f"---\n{new_fm_text}\n---\n{body}"

        if new_content != content:
            print(f"UPDATED: {fname}")
            fpath.write_text(new_content)
            updated_count += 1
        else:
            print(f"UNCHANGED: {fname}")
            unchanged_count += 1

    if args.diff:
        print(f"\nDiff complete. Mismatches found: {mismatches}")
        sys.exit(1 if mismatches > 0 else 0)

    if args.dry_run or args.diff:
        if updated_count == 0 and mismatches == 0:
            info("All files in sync — no changes needed")
    elif updated_count > 0:
        info(f"Updated {updated_count} file(s), {unchanged_count} unchanged")
    else:
        info(f"All files up to date ({unchanged_count} unchanged)")


if __name__ == "__main__":
    main()
