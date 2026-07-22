#!/usr/bin/env python3
"""KodeHold Workspace Manager — create, list, and manage project workspaces.

Usage:
    python3 scripts/workspace.py init <name> [--no-git]
    python3 scripts/workspace.py adopt <name> <path> [--link] [--no-git]
    python3 scripts/workspace.py list [--json] [--loops]
    python3 scripts/workspace.py state <name>
    python3 scripts/workspace.py loop <name> <pattern> [--dry-run]
    python3 scripts/workspace.py gate <name> <transition> [--validate-only]
    python3 scripts/workspace.py deploy-ready <name>
    python3 scripts/workspace.py migrate [<name>|--all]
    python3 scripts/workspace.py deinit <name> [--force]
    python3 scripts/workspace.py ensure-git <name>

Registry migrated from workspaces/.catalog (JSON) to config/workspaces.yaml (YAML).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

import yaml

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
REGISTRY = "config/workspaces.yaml"
GATE_SCRIPT = "scripts/gate.py"


# ── Helpers ───────────────────────────────────────────────────────────────


def validate_slug(slug: str) -> bool:
    """Validate a slug per ADR-0036 format: /^[a-z][a-z0-9-]{0,49}$/"""
    return bool(re.match(r"^[a-z][a-z0-9-]{0,49}$", slug))


# ── Registry (YAML) ───────────────────────────────────────────────────────


def _resolve_workspace_real_path(name: str) -> str:
    """Resolve the real filesystem path for a workspace directory."""
    ws_dir = Path(WORKSPACE_ROOT) / name
    if ws_dir.is_symlink():
        return str(ws_dir.resolve())
    if ws_dir.is_dir():
        return str(ws_dir.resolve())
    return ""


def ensure_registry() -> dict:
    """Load registry from config/workspaces.yaml, migrating from .catalog if needed."""
    reg_path = Path(REGISTRY)
    catalog_path = Path(CATALOG)

    # If registry doesn't exist or is empty, try migration
    if not reg_path.is_file() or reg_path.stat().st_size == 0:
        if catalog_path.is_file():
            return _migrate_catalog_to_registry()

        reg_path.parent.mkdir(parents=True, exist_ok=True)
        reg_path.write_text("workspaces: {}\n")
        return {"workspaces": {}}

    with open(reg_path) as f:
        data = yaml.safe_load(f) or {}
    if "workspaces" not in data:
        data["workspaces"] = {}
    return data


def _migrate_catalog_to_registry() -> dict:
    """Migrate .catalog JSON entries to config/workspaces.yaml."""
    catalog_path = Path(CATALOG)
    reg_path = Path(REGISTRY)

    try:
        catalog = json.loads(catalog_path.read_text())
    except (json.JSONDecodeError, OSError):
        catalog = {}

    reg_path.parent.mkdir(parents=True, exist_ok=True)

    workspaces: dict[str, dict] = {}
    for name, entry in catalog.items():
        real_path = entry.get("real_path", "")
        if not real_path:
            real_path = _resolve_workspace_real_path(name)
        ws_dir = Path(WORKSPACE_ROOT) / name
        state_str = "INIT"
        state_file = ws_dir / ".kodehold-state"
        if state_file.is_file():
            for line in state_file.read_text().splitlines():
                if line.startswith("STATE="):
                    state_str = line.split("=", 1)[1]
                    break

        ws_entry: dict = {
            "created": entry.get("created", date.today().isoformat()),
            "origin": "legacy",
            "state": state_str,
            "real_path": real_path,
            "loops": {
                "enabled": [],
                "last_run": None,
                "run_count": 0,
            },
        }

        # Preserve adopt origin if explicitly marked
        if entry.get("origin") == "adopted":
            ws_entry["origin"] = "adopted"
            ws_entry["adopt"] = {"original_path": entry.get("real_path") or ""}

        workspaces[name] = ws_entry

    data = {"workspaces": workspaces}
    with open(reg_path, "w") as f:
        yaml.dump(data, f, default_flow_style=False)

    count = len(workspaces)
    info(f"Migrated {count} workspaces from .catalog to {REGISTRY}")
    warn("workspaces/.catalog is deprecated — use config/workspaces.yaml instead")

    return data


def registry_write(data: dict) -> None:
    """Write registry data to config/workspaces.yaml."""
    Path(REGISTRY).parent.mkdir(parents=True, exist_ok=True)
    # Sort keys for consistent output
    if "workspaces" in data:
        data["workspaces"] = dict(sorted(data["workspaces"].items()))
    with open(REGISTRY, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)


def _legacy_catalog_warn() -> None:
    """Warn if .catalog is still being used."""
    if Path(CATALOG).is_file():
        warn("workspaces/.catalog is deprecated — use config/workspaces.yaml instead")


# ── Legacy catalog compatibility (for adopt --link reads) ─────────────────


def ensure_catalog() -> dict:
    """Legacy: ensure .catalog exists and return contents (deprecated)."""
    _legacy_catalog_warn()
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
    """Legacy: write .catalog (deprecated)."""
    _legacy_catalog_warn()
    Path(CATALOG).write_text(json.dumps(data, indent=2))


# ── Git helpers ───────────────────────────────────────────────────────────


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


def _git_init_ws(ws_dir: str, name: str, commit_msg: str = "Initial commit") -> None:
    """Init git in workspace and prompt for remote."""
    if git_init(ws_dir, commit_msg):
        pass_msg(f"Git repository initialized at {ws_dir}")
    else:
        warn("git not found — workspace will not have version control")
        prompt_remote(ws_dir, name)
        return
    prompt_remote(ws_dir, name)


# ── Language detection ────────────────────────────────────────────────────


def detect_project_lang(ws_dir: str) -> tuple[str, str, str, int]:
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


# ── Loop file templates ───────────────────────────────────────────────────


def _loop_template(name: str) -> str:
    return f"""# Loop Configuration — {name}

## Active Loops

| Pattern | Cadence | Status | Command |
|---------|---------|--------|---------|
| _(none configured)_ | — | L1 report-only | — |

## Human Gates

- No auto-fix until L2 checklist complete.
- All code changes require human approval.

## Budget

- See loop-budget.md for caps.

## Links

- [STATE.md](STATE.md)
- [Constraints](loop-constraints.md)
- [Budget](loop-budget.md)
"""


def _state_md_template(name: str) -> str:
    return f"""# Loop State — {name}

**Last run:** never

## High Priority

_(none)_

## Watch List

_(none)_

## Recent Noise

_(none)_

---

Run log: ./loop-run-log.md
"""


def _budget_template(name: str) -> str:
    return f"""# Loop Budget — {name}

## Daily limits

| Loop | Max runs/day | Max tokens/day | Max sub-agent spawns/run |
|------|--------------|----------------|--------------------------|
| _(default)_ | 1 | 50k | 0 (L1) |

## Kill switch

- Create `.loop_pause_all` in workspace root to stop all loops.
"""


def _constraints_template(name: str) -> str:
    return f"""# Loop Constraints — {name}

## Push & Merge
- Never push without human approval.

## Protected Paths
- Never edit .env, .env.*, auth/, secrets/, credentials/

## Code
- Always run tests before proposing a fix.
- Max 3 fix attempts per item; escalate after.

## Budget
- If `.loop_pause_all` exists, exit immediately.
"""


def _loop_scaffolding(ws_dir: Path, name: str) -> None:
    """Add loop scaffolding files to a workspace (no overwrite)."""
    scaffolding = {
        "LOOP.md": _loop_template(name),
        "STATE.md": _state_md_template(name),
        "loop-budget.md": _budget_template(name),
        "loop-constraints.md": _constraints_template(name),
    }
    for filename, content in scaffolding.items():
        filepath = ws_dir / filename
        if not filepath.is_file():
            filepath.write_text(content)
            info(f"Created: {filename}")


def _write_kodehold_state(ws_dir: Path, state: str, loop_ready: bool, adopted: bool) -> None:
    """Write .kodehold-state file."""
    today = date.today().isoformat()
    content = f"""# KodeHold Lifecycle State
# Valid states: INIT, ACTIVE, REVIEW, CLOSED, REOPEN
STATE={state}
LOOP_READY={'true' if loop_ready else 'false'}
ADOPTED={'true' if adopted else 'false'}
LAST_UPDATED={today}
DESIGN_DOC_APPROVED=false
ADRS_COMPLETE=false
TESTS_PASSING=false
CODE_REVIEWED=false
"""
    (ws_dir / ".kodehold-state").write_text(content)


# ── Workspace commands ────────────────────────────────────────────────────


def ws_init(name: str, no_git: bool = False) -> None:
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
    for sub in ("docs/design", "docs/adr", "src", "tests"):
        (ws_dir / sub).mkdir(parents=True, exist_ok=True)

    # Design doc template (simpler per spec)
    today = date.today().isoformat()
    design_doc = f"# Design Doc — {name}\n\n## Status\n\n**Active**\n"
    (ws_dir / "docs/design" / "README.md").write_text(design_doc)

    # ADR index
    adr_index = f"""# ADR Index — {name}

| ID | Title | Status |
|----|-------|--------|
"""
    (ws_dir / "docs/adr" / "README.md").write_text(adr_index)

    # State file
    _write_kodehold_state(ws_dir, "INIT", loop_ready=False, adopted=False)

    # .gitignore
    (ws_dir / ".gitignore").write_text("*.pyc\n__pycache__/\n.venv/\n")

    # Loop scaffolding
    _loop_scaffolding(ws_dir, name)

    # Git init
    if not no_git:
        _git_init_ws(str(ws_dir), name, "Initial commit")

    # Register in YAML registry
    registry = ensure_registry()
    registry["workspaces"][name] = {
        "created": today,
        "origin": "init",
        "state": "INIT",
        "real_path": str(ws_dir.resolve()),
        "loops": {
            "enabled": [],
            "last_run": None,
            "run_count": 0,
        },
    }
    registry_write(registry)

    pass_msg(f"Workspace '{name}' created at {ws_dir}")


def ws_adopt(name: str, target_path: str, link: bool = False, no_git: bool = False) -> None:
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
    today = date.today().isoformat()

    if link:
        # --link mode: create symlink (preserves old behavior)
        info(f"Adopting with symlink: {target_resolved} → {ws_dir}")
        ws_dir.parent.mkdir(parents=True, exist_ok=True)
        ws_dir.symlink_to(target_resolved)

        # Create docs dirs inside linked project
        (ws_dir / "docs/design").mkdir(parents=True, exist_ok=True)
        (ws_dir / "docs/adr").mkdir(parents=True, exist_ok=True)

        # State file
        _write_kodehold_state(ws_dir, "ACTIVE", loop_ready=True, adopted=True)

        # Detect project info
        lang, test_framework, build_system, commit_count = detect_project_lang(str(ws_dir))

        # Design doc template
        _write_adopt_design_doc(ws_dir, name, target_resolved, today, lang, test_framework,
                                build_system, commit_count)

        # ADR index
        _write_adopt_adr_index(ws_dir, name)

        # Loop scaffolding
        _loop_scaffolding(ws_dir, name)

        info(f"Project scan complete: {lang}, {commit_count} commits")

        # Git
        if not no_git:
            if not (ws_dir / ".git").is_dir():
                _git_init_ws(str(ws_dir), name, "Initial commit — adopted by KodeHold")
            else:
                _prompt_remote_if_missing(str(ws_dir), name)
    else:
        # Default (copy) mode
        info(f"Adopting project (copy): {target_resolved} → {ws_dir}")
        ws_dir.parent.mkdir(parents=True, exist_ok=True)

        def _ignore_git(src: str, names: list[str]) -> list[str]:
            return [n for n in names if n == ".git"]

        shutil.copytree(
            str(target_resolved), str(ws_dir),
            symlinks=False,
            ignore=_ignore_git,
            ignore_dangling_symlinks=True,
        )

        # Create docs dirs
        (ws_dir / "docs/design").mkdir(parents=True, exist_ok=True)
        (ws_dir / "docs/adr").mkdir(parents=True, exist_ok=True)

        # State file
        _write_kodehold_state(ws_dir, "ACTIVE", loop_ready=True, adopted=True)

        # Detect project info
        lang, test_framework, build_system, commit_count = detect_project_lang(str(ws_dir))

        # Design doc template
        _write_adopt_design_doc(ws_dir, name, target_resolved, today, lang, test_framework,
                                build_system, commit_count)

        # ADR index
        _write_adopt_adr_index(ws_dir, name)

        # Loop scaffolding
        _loop_scaffolding(ws_dir, name)

        info(f"Project scan complete: {lang}, {commit_count} commits")

        # Git
        if not no_git:
            _git_init_ws(str(ws_dir), name, "Initial commit — adopted by KodeHold")

    # Register in YAML registry
    registry = ensure_registry()
    registry["workspaces"][name] = {
        "created": today,
        "origin": "adopted",
        "state": "ACTIVE",
        "real_path": str(ws_dir.resolve()),
        "loops": {
            "enabled": [],
            "last_run": None,
            "run_count": 0,
        },
        "adopt": {
            "original_path": str(target_resolved),
        },
    }
    registry_write(registry)

    pass_msg(f"Adopted '{name}' from {target_resolved}")
    info("Next steps:")
    info("  1. Read design doc at {}docs/design/README.md".format(str(ws_dir)))
    info("  2. Fill in Purpose, Architecture, Components sections")
    info("  3. Run: python3 scripts/workspace.py gate {} INIT_TO_ACTIVE".format(name))
    info("  Note: Adopted projects get relaxed gates — design doc fill-in is the priority")


def _write_adopt_design_doc(ws_dir: Path, name: str, target_resolved: Path,
                            today: str, lang: str, test_framework: str,
                            build_system: str, commit_count: int) -> None:
    """Write design doc for adopted project."""
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


def _write_adopt_adr_index(ws_dir: Path, name: str) -> None:
    """Write ADR index for adopted project."""
    adr_index = f"""# ADR Index — {name} (Adopted Project)

| ADR | Title | Status |
|-----|-------|--------|
"""
    (ws_dir / "docs/adr" / "README.md").write_text(adr_index)


def _prompt_remote_if_missing(ws_dir: str, name: str) -> None:
    """Prompt for remote if no remote configured."""
    result = subprocess.run(
        ["git", "-C", str(ws_dir), "remote", "-v"],
        capture_output=True,
        text=True,
    )
    if not result.stdout.strip():
        prompt_remote(str(ws_dir), name)


def ws_list(json_output: bool = False, loops: bool = False) -> None:
    """List all workspaces."""
    registry = ensure_registry()
    workspaces = registry.get("workspaces", {})
    count = len(workspaces)

    if json_output:
        print(json.dumps(registry, indent=2))
        return

    print()
    print(f"━━━ Workspaces ({count}) ━━━")
    print()

    if count == 0:
        info("No workspaces yet. Create one with: python3 scripts/workspace.py init <name>")
        print()
        return

    if loops:
        header = f"  {'NAME':<20} {'STATE':<12} {'LOOPS':<8} {'LAST RUN':<14} {'UPDATED':<14} PATH"
    else:
        header = f"  {'NAME':<20} {'STATE':<12} {'UPDATED':<14} PATH"
    print(f"  {header}")
    print(f"  {'─' * (86 if loops else 75)}")

    for name, meta in sorted(workspaces.items()):
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

        ws_path = str(ws_dir)
        if not ws_dir.is_dir() and not ws_dir.is_symlink():
            ws_path = "MISSING"

        if loops:
            loop_info = meta.get("loops", {})
            loop_count = loop_info.get("run_count", 0)
            last_run = loop_info.get("last_run") or "—"
            print(f"  {name:<20} {state:<12} {str(loop_count):<8} {str(last_run):<14} {created:<14} {ws_path}")
        else:
            print(f"  {name:<20} {state:<12} {created:<14} {ws_path}")

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


def ws_loop(name: str, pattern: str, dry_run: bool = False) -> None:
    """Run a loop pattern against a workspace."""
    ws_dir = Path(WORKSPACE_ROOT) / name

    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found at {ws_dir}")
        sys.exit(1)

    if not (ws_dir / ".kodehold-state").is_file():
        fail_msg(f"Workspace '{name}' has no .kodehold-state — run migrate first")
        sys.exit(1)

    loop_file = ws_dir / "LOOP.md"
    if not loop_file.is_file():
        fail_msg(f"Workspace '{name}' has no LOOP.md — run migrate first")
        sys.exit(1)

    info(f"Running loop pattern '{pattern}' against workspace '{name}'")

    loop_script = _PROJECT_ROOT / "scripts/loop-run.sh"
    if not loop_script.is_file():
        fail_msg("scripts/loop-run.sh not found — required for loop execution")
        sys.exit(1)

    if dry_run:
        info(f"[DRY RUN] Would run: {loop_script} '{pattern}' in {ws_dir}")
        return

    # Run the loop
    result = subprocess.run(
        [str(loop_script), pattern, f"Run {pattern} against workspace {name}"],
        cwd=str(ws_dir),
    )

    # Update registry
    registry = ensure_registry()
    ws_entry = registry["workspaces"].get(name, {})
    loops_data = ws_entry.get("loops", {})
    enabled = loops_data.get("enabled", [])
    if pattern not in enabled:
        enabled.append(pattern)
    loops_data["enabled"] = enabled
    loops_data["last_run"] = date.today().isoformat()
    loops_data["run_count"] = loops_data.get("run_count", 0) + 1
    ws_entry["loops"] = loops_data
    registry["workspaces"][name] = ws_entry
    registry_write(registry)

    if result.returncode == 0:
        pass_msg(f"Loop '{pattern}' completed for '{name}'")
    else:
        fail_msg(f"Loop '{pattern}' exited with code {result.returncode} for '{name}'")
        sys.exit(result.returncode)


def ws_migrate(name: str) -> None:
    """Add loop scaffolding + registry entry to an existing workspace."""
    ws_dir = Path(WORKSPACE_ROOT) / name

    if not ws_dir.is_dir() and not ws_dir.is_symlink():
        fail_msg(f"Workspace '{name}' not found at {ws_dir}")
        sys.exit(1)

    # Add loop scaffolding
    _loop_scaffolding(ws_dir, name)

    # Update .kodehold-state to add LOOP_READY
    state_file = ws_dir / ".kodehold-state"
    if state_file.is_file():
        text = state_file.read_text()
        if "LOOP_READY" not in text:
            text = text.replace("LAST_UPDATED=", "LOOP_READY=false\nLAST_UPDATED=")
        if "ADOPTED" not in text:
            text = text.replace("LAST_UPDATED=", "ADOPTED=false\nLAST_UPDATED=")
        text = re.sub(
            r"^LAST_UPDATED=.*",
            f"LAST_UPDATED={date.today().isoformat()}",
            text,
            flags=re.MULTILINE,
        )
        state_file.write_text(text)
        info(f"Updated .kodehold-state for '{name}'")

    # Register/update in YAML registry
    registry = ensure_registry()
    ws_entry = registry["workspaces"].get(name, {})

    if not ws_entry:
        # Read state from .kodehold-state
        state_str = "INIT"
        if state_file.is_file():
            for line in state_file.read_text().splitlines():
                if line.startswith("STATE="):
                    state_str = line.split("=", 1)[1]
                    break

        ws_entry = {
            "created": date.today().isoformat(),
            "origin": "legacy",
            "state": state_str,
            "real_path": _resolve_workspace_real_path(name),
            "loops": {
                "enabled": [],
                "last_run": None,
                "run_count": 0,
            },
        }
        registry["workspaces"][name] = ws_entry
        info(f"Registered '{name}' in {REGISTRY}")
    else:
        ws_entry["real_path"] = _resolve_workspace_real_path(name)
        registry["workspaces"][name] = ws_entry

    registry_write(registry)
    pass_msg(f"Migrated '{name}'")


def ws_migrate_all() -> None:
    """Migrate all workspaces + orphaned .catalog entries."""
    registry = ensure_registry()
    migrated_dirs = set()

    # Migrate all directories in workspaces/
    ws_root = Path(WORKSPACE_ROOT)
    if ws_root.is_dir():
        for entry in sorted(ws_root.iterdir()):
            if entry.is_dir() or entry.is_symlink():
                if entry.name.startswith("."):
                    continue
                ws_migrate(entry.name)
                migrated_dirs.add(entry.name)

    # Also handle orphaned .catalog entries (no dir exists)
    catalog_path = Path(CATALOG)
    if catalog_path.is_file():
        try:
            catalog = json.loads(catalog_path.read_text())
        except (json.JSONDecodeError, OSError):
            catalog = {}
        for name, entry in catalog.items():
            if name not in migrated_dirs:
                ws_entry = {
                    "created": entry.get("created", date.today().isoformat()),
                    "origin": "legacy",
                    "state": "INIT",
                    "real_path": entry.get("real_path", ""),
                    "loops": {
                        "enabled": [],
                        "last_run": None,
                        "run_count": 0,
                    },
                }
                registry["workspaces"][name] = ws_entry
                info(f"Registered orphaned .catalog entry '{name}'")

    registry_write(registry)
    pass_msg("All workspaces migrated")


def ws_transition(name: str, transition: str, validate_only: bool = False) -> None:
    """Run a gate transition on a workspace."""
    ws_dir = (Path(WORKSPACE_ROOT) / name).resolve()

    if not ws_dir.is_dir():
        fail_msg(f"Workspace '{name}' not found")
        sys.exit(1)

    # Run gate via subprocess
    gate = Path(GATE_SCRIPT).resolve()
    if gate.is_file():
        cmd = [sys.executable, str(gate), "--project-path", str(ws_dir), "--transition", transition]
        if validate_only:
            cmd.append("--validate-only")
        result = subprocess.run(cmd)
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

    # Also update registry
    registry = ensure_registry()
    if name in registry["workspaces"]:
        registry["workspaces"][name]["state"] = next_state
        registry_write(registry)

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


def ws_deinit(name: str, force: bool = False) -> None:
    """Remove a workspace completely."""
    ws_dir = Path(WORKSPACE_ROOT) / name

    if not ws_dir.is_dir() and not ws_dir.is_symlink():
        fail_msg(f"Workspace '{name}' not found at {ws_dir}")
        sys.exit(1)

    if not force:
        response = input(f"Remove workspace '{name}'? This will delete all files. [y/N] ").strip()
        if response.lower() != "y":
            info("Aborted")
            return

    # Remove symlink marker if present
    loop_state = ws_dir.parent / f".kodehold-loop-state-{name}"
    if loop_state.is_file():
        loop_state.unlink()

    # Remove workspace directory/symlink
    shutil.rmtree(str(ws_dir), ignore_errors=True)
    if ws_dir.is_symlink():
        ws_dir.unlink()

    # Remove from registry
    registry = ensure_registry()
    registry["workspaces"].pop(name, None)
    registry_write(registry)

    pass_msg(f"Workspace '{name}' removed")


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
        warn(f"git not available — cannot initialize '{name}'")
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

    # init
    init_p = sub.add_parser("init", help="Create a new project workspace from scratch")
    init_p.add_argument("name", help="Workspace slug (e.g. my-project)")
    init_p.add_argument("--no-git", action="store_true", help="Skip git initialization")

    # adopt
    adopt_p = sub.add_parser("adopt", help="Adopt an existing project (copy or symlink + KodeHold bootstrap)")
    adopt_p.add_argument("name", help="Workspace slug")
    adopt_p.add_argument("path", help="Path to existing project directory")
    adopt_p.add_argument("--link", action="store_true", help="Create symlink instead of copy")
    adopt_p.add_argument("--no-git", action="store_true", help="Skip git initialization")

    # list
    list_p = sub.add_parser("list", help="List all workspaces")
    list_p.add_argument("--json", action="store_true", help="Output as JSON")
    list_p.add_argument("--loops", action="store_true", help="Include loop info columns")

    # state
    state_p = sub.add_parser("state", help="Show lifecycle state of a workspace")
    state_p.add_argument("name", help="Workspace name")

    # loop
    loop_p = sub.add_parser("loop", help="Run a loop pattern against a workspace")
    loop_p.add_argument("name", help="Workspace name")
    loop_p.add_argument("pattern", help="Loop pattern to run")
    loop_p.add_argument("--dry-run", action="store_true", help="Print what would happen without running")

    # gate
    gate_p = sub.add_parser("gate", help="Run a gate transition on a workspace")
    gate_p.add_argument("name", help="Workspace name")
    gate_p.add_argument("transition", help="Transition (e.g. INIT_TO_ACTIVE)")
    gate_p.add_argument("--validate-only", action="store_true", help="Only validate, do not transition")

    # deploy-ready
    sub.add_parser("deploy-ready", help="Check if workspace is ready to deploy").add_argument(
        "name", help="Workspace name"
    )

    # migrate
    migrate_p = sub.add_parser("migrate", help="Add loop scaffolding and registry entry to workspace(s)")
    migrate_p.add_argument("target", nargs="?", default=None,
                           help="Workspace name (omit with --all for all workspaces)")
    migrate_p.add_argument("--all", action="store_true", dest="migrate_all",
                           help="Migrate all existing workspaces")

    # deinit
    deinit_p = sub.add_parser("deinit", help="Remove a workspace completely")
    deinit_p.add_argument("name", help="Workspace name")
    deinit_p.add_argument("--force", action="store_true", help="Skip confirmation prompt")

    # ensure-git
    sub.add_parser("ensure-git", help="Initialize git repo for an existing workspace (backfill)").add_argument(
        "name", help="Workspace name"
    )

    return parser


def main() -> None:
    """Main entry point."""
    parser = _build_parser()
    args = parser.parse_args()

    # Change to project root
    os.chdir(str(_PROJECT_ROOT))

    if args.command == "migrate":
        _migrate_dispatch(args)()
    else:
        dispatch = {
            "init": lambda: ws_init(args.name, no_git=args.no_git),
            "adopt": lambda: ws_adopt(args.name, args.path, link=args.link, no_git=args.no_git),
            "list": lambda: ws_list(json_output=args.json, loops=args.loops),
            "state": lambda: ws_state(args.name),
            "loop": lambda: ws_loop(args.name, args.pattern, dry_run=args.dry_run),
            "gate": lambda: ws_transition(args.name, args.transition, validate_only=args.validate_only),
            "deploy-ready": lambda: ws_deploy_ready(args.name),
            "deinit": lambda: ws_deinit(args.name, force=args.force),
            "ensure-git": lambda: ws_ensure_git(args.name),
        }
        dispatch[args.command]()


def _migrate_dispatch(args: argparse.Namespace):
    """Dispatch for migrate subcommand (name or --all)."""
    if args.migrate_all:
        return ws_migrate_all
    if args.target:
        return lambda: ws_migrate(args.target)
    # No target and no --all: show help
    return lambda: sys.exit("Usage: workspace.py migrate <name> or workspace.py migrate --all")


if __name__ == "__main__":
    main()
