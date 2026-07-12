"""Shared output formatting for KodeHold scripts.

Provides colored terminal output, JSON mode, and check tracking.
All functions respect JSON_MODE to suppress human-readable output.
"""

from __future__ import annotations

import json
import sys
from typing import Optional

# ANSI color constants
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
NC = "\033[0m"

# Module-level state
_JSON_MODE = False
_JSON_CHECKS: list[dict[str, str]] = []


def set_json_mode(enabled: bool = True) -> None:
    """Enable or disable JSON output mode."""
    global _JSON_MODE
    _JSON_MODE = enabled


def is_json_mode() -> bool:
    """Check if JSON output mode is active."""
    return _JSON_MODE


def pass_msg(msg: str) -> None:
    """Print a green checkmark message (silenced in JSON mode)."""
    if not _JSON_MODE:
        print(f"  {GREEN}✓{NC} {msg}")


def fail_msg(msg: str) -> None:
    """Print a red X message (silenced in JSON mode)."""
    if not _JSON_MODE:
        print(f"  {RED}✗{NC} {msg}")


def warn(msg: str) -> None:
    """Print a yellow warning message (silenced in JSON mode)."""
    if not _JSON_MODE:
        print(f"  {YELLOW}⚠{NC} {msg}")


def info(msg: str) -> None:
    """Print a cyan info message (silenced in JSON mode)."""
    if not _JSON_MODE:
        print(f"  {CYAN}i{NC} {msg}")


def json_add(name: str, status: str, detail: Optional[str] = None) -> None:
    """Record a named check result for JSON output."""
    entry: dict[str, str] = {"name": name, "result": status}
    if detail:
        entry["detail"] = detail
    _JSON_CHECKS.append(entry)


def json_emit(
    script: str,
    result: str,
    version: Optional[str] = None,
    transition: Optional[str] = None,
) -> str:
    """Emit accumulated checks as a JSON object and print it.

    Returns the JSON string for testing/inspection.
    """
    payload: dict = {
        "script": script,
        "result": result,
        "checks": list(_JSON_CHECKS),
    }
    if version:
        payload["version"] = version
    if transition:
        payload["transition"] = transition
    text = json.dumps(payload, indent=2)
    print(text)
    return text


def reset_checks() -> None:
    """Clear accumulated check results (for testing or re-runs)."""
    _JSON_CHECKS.clear()
