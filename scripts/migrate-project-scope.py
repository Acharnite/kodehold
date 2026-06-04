#!/usr/bin/env python3
"""
Migrate `project` field in agentmemory KV store files from full filesystem
paths to canonical slugs.

Usage:
    python3 scripts/migrate-project-scope.py [--dry-run] [--batch N] [--snapshot]
        [--mapping old=new ...] [--file FILE] [--verbose]
"""

import argparse
import json
import os
import shutil
import sys
from collections import defaultdict
from datetime import datetime


DATA_DIR = os.path.expanduser("~/.agentmemory/data/state_store.db")
SNAPSHOT_PATH = os.path.expanduser("~/.agentmemory/snapshots/state.json")

FILES = [
    "mem%3Asessions.bin",
    "mem%3Aactions.bin",
    "mem%3Acrystals.bin",
]

DEFAULT_MAPPINGS = [
    ("/home/kiffer/project/kodehold", "kodehold"),
    ("/home/kiffer/project/bob-ollama", "bob-ollama"),
    ("/home/kiffer/project/bob", "bob"),
    ("/home/kiffer/project", "kodehold"),
]


def parse_mapping_arg(arg):
    """Parse a single --mapping value in 'old=new' format."""
    if "=" not in arg:
        print(f"ERROR: Invalid --mapping format '{arg}'. Use old=new.", file=sys.stderr)
        sys.exit(1)
    old, new = arg.split("=", 1)
    return (old, new)


def build_mappings(cli_mappings):
    """Build mapping list from CLI overrides or defaults.
    Sort by old-prefix length descending so longest prefix is checked first.
    """
    if cli_mappings:
        raw = [parse_mapping_arg(m) for m in cli_mappings]
    else:
        raw = DEFAULT_MAPPINGS
    # Sort by old prefix length descending (longest first)
    raw.sort(key=lambda x: len(x[0]), reverse=True)
    return raw


def match_project(project, mappings):
    """Check if a project field matches any mapping prefix.
    Returns (new_slug, remainder) or None if no match.
    remainder is the part after the prefix (without leading slash), or empty.
    """
    for old_prefix, new_slug in mappings:
        if project == old_prefix:
            return (new_slug, "")
        if project.startswith(old_prefix + "/"):
            remainder = project[len(old_prefix) + 1:]
            return (new_slug, remainder)
    return None


def read_kv_file(filepath):
    """Read a .bin KV file and parse it as JSON.
    Uses errors='replace' for corruption and finds the last '}' for trimming.
    Returns (data, raw_text) or (None, None) on failure.
    """
    try:
        with open(filepath, "rb") as f:
            raw = f.read()
    except IOError as e:
        print(f"  ERROR reading {filepath}: {e}", file=sys.stderr)
        return None, None

    text = raw.decode("utf-8", errors="replace")
    # Find the last '}' to trim trailing garbage
    last_brace = text.rfind("}")
    if last_brace == -1:
        print(f"  ERROR: No closing '}}' found in {filepath}", file=sys.stderr)
        return None, None
    text = text[: last_brace + 1]

    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        print(f"  ERROR: JSON parse error in {filepath}: {e}", file=sys.stderr)
        return None, None

    if not isinstance(data, dict):
        print(f"  ERROR: {filepath} does not contain a JSON object", file=sys.stderr)
        return None, None

    return data, text


def write_kv_file(filepath, data, original_raw=None):
    """Serialize data as compact JSON and write as UTF-8 bytes.

    If original_raw is provided, preserve the binary footer (everything
    after the last '}') that agentmemory's iii-engine requires.
    """
    text = json.dumps(data, indent=None, separators=(",", ":"))
    json_bytes = text.encode("utf-8")

    if original_raw is not None:
        last_brace = original_raw.rfind(b"}")
        if last_brace != -1:
            footer = original_raw[last_brace + 1:]
            json_bytes = json_bytes + footer

    with open(filepath, "wb") as f:
        f.write(json_bytes)
    return True


def take_snapshot():
    """Create a timestamped backup of the entire state_store.db directory."""
    if not os.path.isdir(DATA_DIR):
        print(f"ERROR: Data directory not found: {DATA_DIR}")
        return None

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_dir = os.path.expanduser(
        f"~/.agentmemory/data/state_store.db_backup_{timestamp}"
    )

    try:
        shutil.copytree(DATA_DIR, backup_dir)
        print(f"Snapshot created: {backup_dir}")
        return backup_dir
    except (shutil.Error, OSError) as e:
        print(f"ERROR: Snapshot failed: {e}", file=sys.stderr)
        return None


def process_file(filepath, filename, mappings, args):
    """Process a single KV file. Returns summary stats dict or None on error."""
    basename = filename  # e.g. mem%3Asessions.bin

    print(f"\n--- {basename} ---")

    data, raw_text = read_kv_file(filepath)
    if data is None:
        return None

    total = len(data)
    print(f"  Records: {total}")

    # Scan phase: find all matches
    changes = []  # list of (record_id, old_project, new_project)
    slug_counts = defaultdict(int)

    for record_id, record in data.items():
        if not isinstance(record, dict):
            continue
        project = record.get("project")
        if not isinstance(project, str):
            continue
        match = match_project(project, mappings)
        if match is None:
            continue
        new_slug, remainder = match
        # Build the new project value
        if remainder:
            new_project = f"{new_slug}/{remainder}"
        else:
            new_project = new_slug
        changes.append((record_id, project, new_project))
        slug_counts[new_slug] += 1

    matched = len(changes)
    print(f"  Matched: {matched} / {total}")

    if matched == 0:
        return {
            "file": basename,
            "total": total,
            "matched": 0,
            "slug_counts": {},
        }

    # Batch: limit changes per file
    if args.batch and matched > args.batch:
        changes = changes[: args.batch]
        # Recalculate slug_counts for the batch
        slug_counts = defaultdict(int)
        for _, _, new_project in changes:
            slug = new_project.split("/")[0]
            slug_counts[slug] += 1
        print(f"  Batch mode: applying first {args.batch} of {matched} changes")

    # Verbose output
    if args.verbose:
        for record_id, old_project, new_project in changes:
            print(f"    {record_id}")
            print(f"      project: {old_project} -> {new_project}")

    # Write (unless dry-run)
    if not args.dry_run:
        for record_id, _, new_project in changes:
            data[record_id]["project"] = new_project
        # Read original raw bytes to preserve binary footer
        try:
            with open(filepath, "rb") as f:
                original_raw = f.read()
        except IOError:
            original_raw = None
        if write_kv_file(filepath, data, original_raw):
            print(f"  Wrote: {filepath}")
        else:
            return None
    else:
        print(f"  [DRY RUN] Would write {len(changes)} changes to {basename}")

    return {
        "file": basename,
        "total": total,
        "matched": matched,
        "slug_counts": dict(slug_counts),
    }


def process_snapshot(snapshot_path, mappings, args):
    """Process the agentmemory state snapshot (state.json) sessions array.
    Returns summary stats dict or None on error.
    """
    print(f"\n--- state.json ---")
    print(f"  Path: {snapshot_path}")

    try:
        with open(snapshot_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (IOError, json.JSONDecodeError) as e:
        print(f"  ERROR reading snapshot: {e}", file=sys.stderr)
        return None

    if not isinstance(data, dict):
        print(f"  ERROR: snapshot is not a JSON object", file=sys.stderr)
        return None

    sessions = data.get("sessions", [])
    if not isinstance(sessions, list):
        print(f"  ERROR: 'sessions' is not an array", file=sys.stderr)
        return None

    total = len(sessions)
    print(f"  Sessions: {total}")

    # Scan phase: find all matches
    changes = []  # list of (index, old_project, new_project)
    slug_counts = defaultdict(int)

    for idx, session in enumerate(sessions):
        if not isinstance(session, dict):
            continue
        project = session.get("project")
        if not isinstance(project, str):
            continue
        match = match_project(project, mappings)
        if match is None:
            continue
        new_slug, remainder = match
        if remainder:
            new_project = f"{new_slug}/{remainder}"
        else:
            new_project = new_slug
        changes.append((idx, project, new_project))
        slug_counts[new_slug] += 1

    matched = len(changes)
    print(f"  Matched: {matched} / {total}")

    if matched == 0:
        return {
            "file": "state.json",
            "total": total,
            "matched": 0,
            "slug_counts": {},
        }

    # Batch: limit changes
    if args.batch and matched > args.batch:
        changes = changes[: args.batch]
        slug_counts = defaultdict(int)
        for _, _, new_project in changes:
            slug = new_project.split("/")[0]
            slug_counts[slug] += 1
        print(f"  Batch mode: applying first {args.batch} of {matched} changes")

    # Verbose output
    if args.verbose:
        for idx, old_project, new_project in changes:
            session_id = sessions[idx].get("id", f"[index {idx}]")
            print(f"    {session_id}")
            print(f"      project: {old_project} -> {new_project}")

    # Write (unless dry-run)
    if not args.dry_run:
        for idx, _, new_project in changes:
            sessions[idx]["project"] = new_project
        data["sessions"] = sessions
        try:
            with open(snapshot_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"  Wrote: {snapshot_path}")
        except IOError as e:
            print(f"  ERROR writing snapshot: {e}", file=sys.stderr)
            return None
    else:
        print(f"  [DRY RUN] Would write {len(changes)} changes to state.json")

    return {
        "file": "state.json",
        "total": total,
        "matched": matched,
        "slug_counts": dict(slug_counts),
    }


def print_summary(results):
    """Print a formatted summary table of results."""
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)

    # Column widths
    col1 = "Collection"
    col2 = "Total"
    col3 = "Matched"
    col4 = "Mapped to"

    # Calculate max width needed for mapped-to column
    max_slug_items = 0
    for r in results:
        if r is None:
            continue
        n = len(r["slug_counts"])
        if n > max_slug_items:
            max_slug_items = n

    header = f"  {col1:<28} {col2:>6} {col3:>8}   {col4}"
    sep_len = len(header)
    sep = "  " + "─" * (sep_len - 2)

    print(header)
    print(sep)

    any_errors = False
    for r in results:
        if r is None:
            any_errors = True
            continue
        slug_parts = []
        for slug, count in sorted(r["slug_counts"].items()):
            slug_parts.append(f"{slug} ({count})")
        slug_str = ", ".join(slug_parts) if slug_parts else "—"
        # 3 display name from filename
        display = r["file"].replace("mem%3A", "").replace(".bin", "")
        print(f"  {display:<28} {r['total']:>6} {r['matched']:>8}   {slug_str}")

    print(sep)
    total_all = sum(r["total"] for r in results if r is not None)
    matched_all = sum(r["matched"] for r in results if r is not None)
    print(f"  {'TOTAL':<28} {total_all:>6} {matched_all:>8}")
    print()

    if any_errors:
        print("WARNING: Some files had errors (see above).")
        print()


def main():
    parser = argparse.ArgumentParser(
        description="Migrate project field in agentmemory KV files from filesystem paths to canonical slugs"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only show what would change, don't write anything",
    )
    parser.add_argument(
        "--batch",
        type=int,
        default=0,
        help="Process N records per collection then stop (for incremental migration)",
    )
    parser.add_argument(
        "--snapshot",
        action="store_true",
        help="Create a full timestamped backup of the data directory before any changes",
    )
    parser.add_argument(
        "--mapping",
        action="append",
        dest="mappings",
        default=[],
        help="Override default mappings. Format: old=new (can be specified multiple times)",
    )
    parser.add_argument(
        "--file",
        type=str,
        default=None,
        help="Only process specific file (e.g. mem%%3Asessions.bin)",
    )
    parser.add_argument(
        "--state-snapshot",
        action="store_true",
        default=False,
        help="Also update project fields in the agentmemory state snapshot (state.json)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show each individual record change",
    )
    args = parser.parse_args()

    # Validate data directory
    if not os.path.isdir(DATA_DIR):
        print(f"ERROR: Data directory not found: {DATA_DIR}", file=sys.stderr)
        sys.exit(1)

    # Build mappings
    mappings = build_mappings(args.mappings)
    print(f"Using {len(mappings)} mapping(s):")
    for old_prefix, new_slug in mappings:
        print(f"  {old_prefix} -> {new_slug}")

    # Determine which files to process
    files_to_process = FILES
    if args.file:
        if args.file not in FILES:
            print(
                f"WARNING: Specified file '{args.file}' is not in the expected list."
            )
        files_to_process = [args.file]

    # Snapshot
    if args.snapshot:
        backup_dir = take_snapshot()
        if backup_dir is None:
            sys.exit(1)

    # Process each file
    results = []
    for filename in files_to_process:
        filepath = os.path.join(DATA_DIR, filename)
        if not os.path.isfile(filepath):
            print(f"\n--- {filename} ---")
            print(f"  ERROR: File not found: {filepath}", file=sys.stderr)
            results.append(None)
            continue
        result = process_file(filepath, filename, mappings, args)
        results.append(result)

    # Process state snapshot
    if args.state_snapshot or os.path.isfile(SNAPSHOT_PATH):
        snap_path = SNAPSHOT_PATH
        if os.path.isfile(snap_path):
            snap_result = process_snapshot(snap_path, mappings, args)
            results.append(snap_result)
        else:
            print(f"\n--- state.json ---")
            print(f"  WARNING: Snapshot not found: {snap_path}")

    # Summary
    print_summary(results)

    if args.dry_run:
        print("DRY RUN - No changes written")

    # Return code
    if any(r is None for r in results):
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
