#!/usr/bin/env python3
"""Token usage per agent for the current KodeHold project.

Queries OpenCode's SQLite database for aggregated token counts.

Usage:
    python3 scripts/token_usage.py                         # Default: project=kodehold, last 60 min
    python3 scripts/token_usage.py --project my-project
    python3 scripts/token_usage.py --minutes 120
    python3 scripts/token_usage.py --project kodehold --minutes 1440
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Query OpenCode token usage per agent"
    )
    parser.add_argument("--project", type=str, default="kodehold", help="Project name (default: kodehold)")
    parser.add_argument("--minutes", type=int, default=60, help="Time window in minutes (default: 60)")
    args = parser.parse_args()

    project = args.project
    minutes = args.minutes

    # Locate OpenCode DB
    db_path = Path.home() / ".local" / "share" / "opencode" / "opencode.db"
    if not db_path.is_file():
        print(f"OpenCode database not found at {db_path}", file=sys.stderr)
        sys.exit(1)

    # Calculate cutoff timestamp (seconds since epoch)
    cutoff = int(datetime.now(timezone.utc).timestamp()) - (minutes * 60)

    # Sanitize project name to prevent SQL injection
    sanitized_project = re.sub(r"[^a-zA-Z0-9\-]", "", project)

    try:
        conn = sqlite3.connect(str(db_path))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()

        cursor.execute("""
            SELECT
                s.agent,
                SUM(s.tokens_input) AS tokens_input,
                SUM(s.tokens_output) AS tokens_output,
                SUM(s.tokens_input + s.tokens_output) AS total_tokens,
                COUNT(*) AS session_count
            FROM session s
            JOIN project p ON s.project_id = p.id
            WHERE p.worktree LIKE ?
                AND s.time_created >= ?
                AND s.agent IS NOT NULL
            GROUP BY s.agent
            ORDER BY total_tokens DESC
        """, (f"%{sanitized_project}%", cutoff))

        rows = cursor.fetchall()
        conn.close()

    except sqlite3.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)

    # Format as JSON (matching sqlite3 -json behavior)
    result = []
    for row in rows:
        result.append({
            "agent": row["agent"],
            "tokens_input": row["tokens_input"] or 0,
            "tokens_output": row["tokens_output"] or 0,
            "total_tokens": row["total_tokens"] or 0,
            "session_count": row["session_count"] or 0,
        })

    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
