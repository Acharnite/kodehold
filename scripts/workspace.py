#!/usr/bin/env python3
"""KodeHold Workspace Manager — create, list, and manage project workspaces.

Usage:
    python3 scripts/workspace.py init <name>
    python3 scripts/workspace.py adopt <name> <path>
    python3 scripts/workspace.py list
    python3 scripts/workspace.py state <name>
    python3 scripts/workspace.py gate <name> <transition>
    python3 scripts/workspace.py deploy-ready <name>
    python3 scripts/workspace.py ensure-git <name>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

# Ensure project root is in sys.path
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

from scripts.lib.output import (  # noqa: E402
    pass_msg,
    fail_msg,
    warn,
    info,
)

WORKSPACE_ROOT = "workspaces"
CATALOG = f"{WORKSPACE_ROOT}/.catalog"
GATE_SCRIPT = "scripts/gate.py"


# ── Helpers ───────────────────────────────────────────────────────────────


def validate_slug(slug: str) -> bool:
    """Validate a slug per ADR-0036 format: /^[a-z][a-z0-9-]{0,49}$/"""
    return bool(re.match(r"^[a-z][a-z0-9-]{0,49}$", slug))


def ensure_catalog() -> dict:
    """Ensure the catalog file exists and return its contents."""
    cat_path = Path(CATALOG)
    if not cat_path.is_file():
        cat_path.parent.mkdir(parents=True, exist_ok=True)
        cat_path.write_text("{}")
        return {}
    try:
        return json.loads(cat_path.read_text())
    except (json.JSONDecodeError, OSError):
        return {}


def catalog_write(data: dict) -> None:
    """Write catalog data."""
    Path(CATALOG).write_text(json.dumps(data, indent=2))


def prompt_remote(ws_dir: str, label: str = "Workspace") -> None:
    """Prompt user to add a git remote."""
    remote_url = input(f"  i Add a git remote for {label}? (URL or empty to skip): ").strip()
    if remote_url:
        result = subprocess.run(
            ["git", "-C", ws_dir, "remote", "add", "origin", remote_url],
            capture_output=True,
        )
        if result.returncode == 0:
            pass_msg(f"Remote 'origin' added: {remote_url}")
        else:
            warn("Failed to add remote — check the URL")
    else:
        info("Skipped remote setup")


def git_init(ws_dir: str, commit_msg: str = "Initial commit") -> bool:
    """Initialize a git repository in ws_dir and make initial commit."""
    try:
        if subprocess.run(["git", "init", ws_dir], capture_output=True).returncode != 0:
            return False
        subprocess.run(
            ["git", "-C", ws_dir, "add", "-A"], capture_output=True
        )
        subprocess.run(
            ["git", "-C", ws_dir, "commit", "-m", commit_msg],
            capture_output=True,
        )
        return True
    except OSError:
        return False


def detect_project_lang(ws_dir: str) -> tuple[str, str, str, str]:
    """Detect language, test framework, and build system for a project."""
    lang = "Unknown"
    test_framework = ""
    build_system = ""
    commit_count = 0

    # Count commits
    if (Path(ws_dir) / ".git").is_dir():
        try:
            result = subprocess.run(
                ["git", "-C", ws_dir, "log", "--oneline"],
                capture_output=True,
                text=True,
            )
            commit_count = len(result.stdout.strip().splitlines()) if result.stdout.strip() else 0
        except OSError:
            pass

    pkg_json = Path(ws_dir) / "package.json"
    cargo_toml = Path(ws_dir) / "Cargo.toml"
    pyproject = Path(ws_dir) / "pyproject.toml"
    go_mod = Path(ws_dir) / "go.mod"
    makefile = Path(ws_dir) / "Makefile"

    if pkg_json.is_file():
        lang = "JavaScript/TypeScript"
        text = pkg_json.read_text()
        for fw in ("jest", "vitest", "mocha", "playwright"):
            if fw in text:
                test_framework = fw
                break
        m = re.search(r'"build":\s*"[^"]+"', text)
        if m:
            build_system = m.group(0)
        return lang, test_framework, build_system, commit_count

    if cargo_toml.is_file():
        return "Rust", "cargo test (built-in)", "cargo", commit_count

    if pyproject.is_file():
        lang = "Python"
        text = pyproject.read_text()
        if "pytest" in text:
            test_framework = "pytest"
        elif "unittest" in text:
            test_framework = "unittest"
        else:
            test_framework = "pytest"
        build_system = "pip/setuptools"
        return lang, test_framework, build_system, commit_count

    if go_mod.is_file():
        return "Go", "go test (built-in)", "go build", commit_count

    if makefile.is_file():
        return "Unknown (has Makefile)", "", "make", commit_count

    return lang, test_framework, build_system, commit_count


# ── Workspace commands ────────────────────────────────────────────────────


def ws_init(name: str) -> None:
    """Create a new project workspace from scratch."""
    ws_dir = Path(WORKSPACE_ROOT) / name

    if not validate_slug(name):
        fail_msg(
            f"Invalid workspace name '{name}' — must match slug pattern: ^[a-z][a-z0-9-]{{0,49}}$"
        )
        sys.exit(1)

    if ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' already exists at {ws_dir}")
        sys.exit(1)

    info(f"Creating workspace: {name}")

    # Create directory structure
    for sub in ("docs/design", "docs/adr", "docs/decisions", "src", "tests"):
        (ws_dir / sub).mkdir(parents=True, exist_ok=True)

    today = date.today().isoformat()

    # Design doc template
    design_doc = f"""# {name} — Design Document
**Version:** 0.1
**Status:** Draft
**Design Authority:** Architects
**Last Reviewed:** {today}

## 1. Purpose & Scope
## 2. Requirements
## 3. Architecture Overview
## 4. Component Design
## 5. Data Model
## 6. API Design
## 7. Implementation Plan
## 8. Testing Strategy
## 9. ADR Index
## 10. Open Questions
## 11. Changelog
"""
    (ws_dir / "docs/design" / "README.md").write_text(design_doc)

    # ADR index
    adr_index = f"""# ADR Index — {name}

| ADR | Title | Status |
|-----|-------|--------|
"""
    (ws_dir / "docs/adr" / "README.md").write_text(adr_index)

    # State file
    state = f"""# KodeHold Lifecycle State
# Valid states: INIT, ACTIVE, REVIEW, CLOSED, REOPEN
STATE=INIT
LAST_UPDATED={today}
DESIGN_DOC_APPROVED=false
ADRS_COMPLETE=false
TESTS_PASSING=false
CODE_REVIEWED=false
"""
    (ws_dir / ".kodehold-state").write_text(state)

    # .gitignore
    (ws_dir / ".gitignore").write_text("*.pyc\n__pycache__/\n.venv/\n")

    # Git init
    if git_init(str(ws_dir), "Initial commit"):
        pass_msg(f"Git repository initialized at {ws_dir}")
    else:
        warn("git not found — workspace will not have version control")
        prompt_remote(str(ws_dir), name)
        return

    prompt_remote(str(ws_dir), name)

    # Register in catalog
    catalog = ensure_catalog()
    catalog[name] = {"created": today, "project": name}
    catalog_write(catalog)

    pass_msg(f"Workspace '{name}' created at {ws_dir}")


def ws_adopt(name: str, target_path: str) -> None:
    """Adopt an existing project into a workspace."""
    ws_dir = Path(WORKSPACE_ROOT) / name

    if not validate_slug(name):
        fail_msg(
            f"Invalid workspace name '{name}' — must match slug pattern: ^[a-z][a-z0-9-]{{0,49}}$"
        )
        sys.exit(1)

    if ws_dir.exists():
        fail_msg(f"Workspace '{name}' already exists at {ws_dir}")
        sys.exit(1)

    target = Path(target_path)
    if not target.is_dir():
        fail_msg(f"Target path does not exist: {target}")
        sys.exit(1)

    target_resolved = target.resolve()

    info(f"Adopting existing project: {target_resolved} → {ws_dir}")

    # Create symlink
    ws_dir.parent.mkdir(parents=True, exist_ok=True)
    ws_dir.symlink_to(target_resolved)

    # Create KodeHold artifacts inside the adopted project
    (ws_dir / "docs/design").mkdir(parents=True, exist_ok=True)
    (ws_dir / "docs/adr").mkdir(parents=True, exist_ok=True)

    today = date.today().isoformat()

    # State file with ADOPTED flag
    state = f"""# KodeHold Lifecycle State — Adopted Project
# Valid states: INIT, ACTIVE, REVIEW, CLOSED, REOPEN
STATE=INIT
ADOPTED=true
LAST_UPDATED={today}
DESIGN_DOC_APPROVED=false
ADRS_COMPLETE=false
TESTS_PASSING=false
CODE_REVIEWED=false
"""
    (ws_dir / ".kodehold-state").write_text(state)

    # Detect project info
    lang, test_framework, build_system, commit_count = detect_project_lang(str(ws_dir))

    # Design doc template
    design_doc = f"""# {name} — Design Document
**Version:** 0.1
**Status:** Draft
**Design Authority:** Architects
**Last Reviewed:** {today}
**Origin:** Adopted ({target_resolved})

> Project adopted by KodeHold on {today}. It was not originally created with KodeHold.
> This design document is a retroactive description of the existing codebase.

## 1. Purpose & Scope
_Describe what this project does — derived from existing code._

## 2. Requirements
_Reverse-engineered from existing functionality._

## 3. Architecture Overview
_Describe the existing architecture._

- Language: {lang}
- Build system: {build_system}
- Test framework: {test_framework or "None detected"}
- {commit_count} git commits

## 4. Component Design
_Catalogue existing components and modules._

## 5. Data Model
_Document existing data structures and schemas._

## 6. API Design
_Document existing API endpoints and interfaces._

## 7. Implementation Plan
_No forward plan — this project is already implemented. Use for feature additions._

## 8. Testing Strategy
_Describe existing test approach._

- Test framework: {test_framework or "Not detected"}
- _Add test discovery results here_

## 9. ADR Index
_Record architectural decisions retroactively as ADRs._

## 10. Open Questions
_What needs to be understood about the codebase._

## 11. Changelog
- {today}: Adopted by KodeHold — design doc created retroactively
"""
    (ws_dir / "docs/design" / "README.md").write_text(design_doc)

    # ADR index
    adr_index = f"""# ADR Index — {name} (Adopted Project)

| ADR | Title | Status |
|-----|-------|--------|
"""
    (ws_dir / "docs/adr" / "README.md").write_text(adr_index)

    info(f"Project scan complete: {lang}, {commit_count} commits")

    # Ensure git
    if not (ws_dir / ".git").is_dir():
        if git_init(str(ws_dir), "Initial commit — adopted by KodeHold"):
            pass_msg(f"Git repository initialized at {ws_dir}")
            prompt_remote(str(ws_dir), name)
        else:
            warn("git init failed — adopted project will not have version control")
    else:
        # Still prompt for remote if none exists
        result = subprocess.run(
            ["git", "-C", str(ws_dir), "remote", "-v"],
            capture_output=True,
            text=True,
        )
        if not result.stdout.strip():
            prompt_remote(str(ws_dir), name)

    # Register in catalog
    catalog = ensure_catalog()
    catalog[name] = {
        "created": today,
        "project": name,
        "origin": "adopted",
        "real_path": str(target_resolved),
    }
    catalog_write(catalog)

    pass_msg(f"Adopted '{name}' from {target_resolved}")
    info("Next steps:")
    info("  1. Read design doc at {}docs/design/README.md".format(str(ws_dir)))
    info("  2. Fill in Purpose, Architecture, Components sections")
    info("  3. Run: python3 scripts/workspace.py gate {} INIT_TO_ACTIVE".format(name))
    info("  Note: Adopted projects get relaxed gates — design doc fill-in is the priority")


def ws_list() -> None:
    """List all workspaces."""
    catalog = ensure_catalog()
    count = len(catalog)

    print()
    print(f"━━━ Workspaces ({count}) ━━━")
    print()

    if count == 0:
        info("No workspaces yet. Create one with: python3 scripts/workspace.py init <name>")
        print()
        return

    print(f"  {'NAME':<20} {'STATE':<12} {'UPDATED':<14} PATH")
    print(f"  {'─' * 75}")

    for name, meta in sorted(catalog.items()):
        created = meta.get("created", "N/A")
        ws_dir = Path(WORKSPACE_ROOT) / name

        # Read state from .kodehold-state
        state = "N/A"
        state_file = ws_dir / ".kodehold-state"
        if state_file.is_file():
            for line in state_file.read_text().splitlines():
                if line.startswith("STATE="):
                    state = line.split("=", 1)[1]
                    break

        if ws_dir.is_dir():
            print(f"  {name:<20} {state:<12} {created:<14} {ws_dir}")
        else:
            print(f"  {name:<20} {state:<12} {created:<14} MISSING")

    print()


def ws_state(name: str) -> None:
    """Show lifecycle state of a workspace."""
    ws_dir = Path(WORKSPACE_ROOT) / name
    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found")
        sys.exit(1)

    state_file = ws_dir / ".kodehold-state"
    if state_file.is_file():
        print(state_file.read_text(), end="")
    else:
        info("No .kodehold-state found — workspace not initialized with lifecycle")


def ws_transition(name: str, transition: str) -> None:
    """Run a gate transition on a workspace."""
    ws_dir = (Path(WORKSPACE_ROOT) / name).resolve()

    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found")
        sys.exit(1)

    # Run gate via subprocess
    gate = Path(GATE_SCRIPT).resolve()
    if gate.is_file():
        result = subprocess.run(
            [sys.executable, str(gate), "--project-path", str(ws_dir), "--transition", transition],
        )
        if result.returncode == 0:
            pass_msg(f"Gate {transition} passed for '{name}'")
        else:
            fail_msg(f"Gate {transition} BLOCKED for '{name}' — fix before transition")
            sys.exit(1)

    # Update state file
    next_state_map = {
        "INIT_TO_ACTIVE": "ACTIVE",
        "ACTIVE_TO_REVIEW": "REVIEW",
        "REVIEW_TO_CLOSED": "CLOSED",
        "CLOSED_TO_REOPEN": "REOPEN",
        "REOPEN_TO_ACTIVE": "ACTIVE",
    }
    next_state = next_state_map.get(transition)
    if not next_state:
        fail_msg(f"Unknown transition: {transition}")
        sys.exit(1)

    state_file = ws_dir / ".kodehold-state"
    if state_file.is_file():
        text = state_file.read_text()
        text = re.sub(r"^STATE=.*", f"STATE={next_state}", text, flags=re.MULTILINE)
        text = re.sub(
            r"^LAST_UPDATED=.*",
            f"LAST_UPDATED={date.today().isoformat()}",
            text,
            flags=re.MULTILINE,
        )
        state_file.write_text(text)

    pass_msg(f"Transitioned '{name}' to {next_state}")


def ws_deploy_ready(name: str) -> None:
    """Check if workspace is ready to deploy."""
    ws_dir = Path(WORKSPACE_ROOT) / name
    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found")
        sys.exit(1)

    state_file = ws_dir / ".kodehold-state"
    state = ""
    if state_file.is_file():
        for line in state_file.read_text().splitlines():
            if line.startswith("STATE="):
                state = line.split("=", 1)[1]
                break

    if state == "CLOSED":
        pass_msg(f"'{name}' is CLOSED — ready for deploy")
    else:
        info(f"'{name}' is {state} — must reach CLOSED before deploy")
        info("  Current path: INIT → ACTIVE → REVIEW → CLOSED")
        sys.exit(1)


def ws_ensure_git(name: str) -> None:
    """Initialize git repo for an existing workspace (backfill)."""
    ws_dir = Path(WORKSPACE_ROOT) / name
    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found")
        sys.exit(1)

    if (ws_dir / ".git").is_dir():
        pass_msg(f"'{name}' already has a git repository")
        return

    if git_init(str(ws_dir), "Initial commit — backfilled by KodeHold"):
        pass_msg(f"Git repository initialized for '{name}'")
        prompt_remote(str(ws_dir), name)
    else:
        warn("git not available — cannot initialize '{name}'")
        sys.exit(1)


# ── CLI ───────────────────────────────────────────────────────────────────


def _build_parser() -> argparse.ArgumentParser:
    """Build the argument parser with subcommands."""
    parser = argparse.ArgumentParser(
        prog="workspace.py",
        description="KodeHold Workspace Manager — create, list, and manage project workspaces",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Transitions:
  INIT_TO_ACTIVE, ACTIVE_TO_REVIEW, REVIEW_TO_CLOSED,
  CLOSED_TO_REOPEN, REOPEN_TO_ACTIVE""",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    init_p = sub.add_parser("init", help="Create a new project workspace from scratch")
    init_p.add_argument("name", help="Workspace slug (e.g. my-project)")

    adopt_p = sub.add_parser("adopt", help="Adopt an existing project (symlink + KodeHold bootstrap)")
    adopt_p.add_argument("name", help="Workspace slug")
    adopt_p.add_argument("path", help="Path to existing project directory")

    sub.add_parser("list", help="List all workspaces")

    state_p = sub.add_parser("state", help="Show lifecycle state of a workspace")
    state_p.add_argument("name", help="Workspace name")

    gate_p = sub.add_parser("gate", help="Run a gate transition on a workspace")
    gate_p.add_argument("name", help="Workspace name")
    gate_p.add_argument("transition", help="Transition (e.g. INIT_TO_ACTIVE)")

    deploy_p = sub.add_parser("deploy-ready", help="Check if workspace is ready to deploy")
    deploy_p.add_argument("name", help="Workspace name")

    git_p = sub.add_parser("ensure-git", help="Initialize git repo for an existing workspace (backfill)")
    git_p.add_argument("name", help="Workspace name")

    return parser


def main() -> None:
    """Main entry point."""
    parser = _build_parser()
    args = parser.parse_args()

    # Change to project root
    os.chdir(str(_PROJECT_ROOT))

    dispatch = {
        "init": lambda: ws_init(args.name),
        "adopt": lambda: ws_adopt(args.name, args.path),
        "list": lambda: ws_list(),
        "state": lambda: ws_state(args.name),
        "gate": lambda: ws_transition(args.name, args.transition),
        "deploy-ready": lambda: ws_deploy_ready(args.name),
        "ensure-git": lambda: ws_ensure_git(args.name),
    }
    dispatch[args.command]()


if __name__ == "__main__":
    main()
