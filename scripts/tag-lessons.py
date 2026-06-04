#!/usr/bin/env python3
"""
tag-lessons.py — Batch update agentmemory lessons with team tags.

Fetches all lessons from agentmemory, determines team tag from content
keywords, normalizes project field, and creates companion lessons with
correct tags (since existing lessons cannot have tags updated in-place).

Usage:
    python3 scripts/tag-lessons.py              # Apply updates
    python3 scripts/tag-lessons.py --dry-run     # Preview only
    python3 scripts/tag-lessons.py --stats       # Summary counts
    python3 scripts/tag-lessons.py --verbose     # Detailed output
    python3 scripts/tag-lessons.py --dry-run --stats --verbose  # Full preview
"""

import argparse
import json
import re
import sys
import urllib.request
import urllib.error

AGENTMEMORY_URL = "http://localhost:3111"
LESSONS_ENDPOINT = f"{AGENTMEMORY_URL}/agentmemory/lessons"

# Keyword -> team mapping.
# Priority order: fls > testers > reviewers > architects > scribes > director > engineers
# If a lesson matches keywords for multiple teams, first match wins (highest priority).
TEAM_RULES = [
    # Priority 1: FLS (hotfix/bug/triage content)
    ("fls", ["hotfix", "bug", "patch", "retry", "error", "investigate", "triage"]),
    # Priority 2: Testers (testing patterns)
    ("testers", ["test", "testing", "regression", "coverage", "pytest", "test_suite"]),
    # Priority 3: Reviewers (review patterns)
    ("reviewers", ["review", "approve", "quality", "standards", "code review"]),
    # Priority 4: Architects (design patterns)
    ("architects", ["architecture", "design", "adr", "pattern", "decision"]),
    # Priority 5: Scribes (documentation patterns)
    ("scribes", ["document", "doc", "changelog", "version", "memory", "session", "checkpoint"]),
    # Priority 6: Director (protocol/action patterns)
    ("director", ["crystal", "signal", "routine", "action", "protocol"]),
    # Priority 7: Engineers (implementation patterns — lowest priority, catch-all)
    ("engineers", ["implement", "code", "refactor", "bugfix", "library", "api"]),
]

# Tag used to identify companion lessons created by this script
BATCH_MARKER = "batch-tagged-v1"


def fetch_lessons(limit=500):
    """Fetch all lessons from agentmemory."""
    url = f"{LESSONS_ENDPOINT}?limit={limit}"
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as e:
        print(f"ERROR: Failed to fetch lessons: {e}", file=sys.stderr)
        sys.exit(1)

    lessons = data.get("lessons", data if isinstance(data, list) else [])
    return lessons


def determine_team(content):
    """Determine team tag from lesson content using keyword matching.

    Priority order: fls > testers > reviewers > architects > scribes > director > engineers.
    First match wins.
    """
    content_lower = content.lower()
    for team, keywords in TEAM_RULES:
        for kw in keywords:
            if kw in content_lower:
                return team
    return "scribes"  # Default fallback


def needs_team_tag(tags):
    """Check if lesson already has a team tag (one of the known team names)."""
    if not tags:
        return True
    known_teams = {team for team, *_ in TEAM_RULES}
    for tag in tags:
        tag_lower = tag.lower().strip()
        if tag_lower in known_teams:
            return False
    return True


def needs_topic_tag(tags):
    """Check if lesson already has the kodehold-learnings topic tag."""
    return "kodehold-learnings" not in [t.lower() for t in (tags or [])]


def needs_project_fix(project):
    """Check if project field starts with the filesystem path pattern (CR1)."""
    if not project:
        return True
    return project.startswith("/home/kiffer/project/kodehold")


def should_normalize_project(project):
    """Check if project needs normalization to 'kodehold'."""
    return needs_project_fix(project)


def has_batch_marker(content, tags):
    """Check if this lesson was already created by a previous batch run."""
    if tags and BATCH_MARKER in tags:
        return True
    if content and BATCH_MARKER in content:
        return True
    return False


def save_lesson(content, tags, project, confidence=0.5, verbose=False):
    """Save a lesson via POST /agentmemory/lessons.

    If content matches an existing lesson, tags won't be updated (auto-strengthen).
    We use a unique content suffix to ensure creation of a new lesson with correct tags.
    """
    payload = json.dumps({
        "content": content,
        "tags": tags,
        "project": project,
        "confidence": confidence,
    }).encode("utf-8")

    req = urllib.request.Request(
        LESSONS_ENDPOINT,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            if verbose:
                action = result.get("action", "unknown")
                lesson_info = result.get("lesson", {})
                lesson_id = lesson_info.get("id", "?")
                print(f"    → {action}: lesson {lesson_id}")
            return result
    except (urllib.error.URLError, urllib.error.HTTPError) as e:
        print(f"    ERROR: Failed to save: {e}", file=sys.stderr)
        return None


def check_has_companions(lessons):
    """Check if companion lessons already exist for any of the source lessons.

    Returns the set of content strings (minus marker suffix) that already have companions.
    """
    companion_contents = set()
    for lesson in lessons:
        tags = lesson.get("tags") or []
        content = lesson.get("content", "")
        if BATCH_MARKER in tags:
            # Strip the marker suffix to get original content
            stripped = content.rstrip()
            marker = f"[{BATCH_MARKER}]"
            if stripped.endswith(marker):
                companion_contents.add(stripped[: -len(marker)].rstrip())
            else:
                companion_contents.add(stripped)
    return companion_contents


def main():
    parser = argparse.ArgumentParser(
        description="Batch-tag agentmemory lessons with team tags."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without applying",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed per-lesson output",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print summary statistics only",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow re-running even if companions already exist",
    )
    args = parser.parse_args()

    # Fetch all lessons
    lessons = fetch_lessons()

    total = len(lessons)
    missing_team = 0
    missing_topic = 0
    needs_project = 0
    already_tagged = 0
    skipped_marker = 0
    would_create = 0
    team_counts = {}

    if args.dry_run and args.stats:
        mode_msg = "DRY RUN (no changes)"
    elif args.dry_run:
        mode_msg = "DRY RUN (no changes)"
    else:
        mode_msg = "APPLYING changes"

    print(f"Tag-Lessons Batch Update - {mode_msg}")
    print(f"Total lessons fetched: {total}")
    print()

    # Build set of original content that already has companion lessons (idempotency)
    companion_original_contents = check_has_companions(lessons)
    if companion_original_contents and not args.force:
        print(f"NOTE: {len(companion_original_contents)} companion lessons already exist.")
        print("Use --force to re-create companions. Skipping existing companions.\n")

    for i, lesson in enumerate(lessons):
        lesson_id = lesson.get("id", f"#{i}")
        content = lesson.get("content", "")
        tags = lesson.get("tags") or []
        project = lesson.get("project") or ""

        # Determine what this lesson needs
        team = determine_team(content)
        team_tag_missing = needs_team_tag(tags)
        topic_tag_missing = needs_topic_tag(tags)
        project_needs_fix = should_normalize_project(project)
        is_batch_marker = has_batch_marker(content, tags)

        if is_batch_marker:
            skipped_marker += 1
            if args.verbose:
                print(f"  [{i}] {lesson_id[:16]}... SKIP (already batch-tagged)")
            continue

        # Skip if a companion already exists for this content (idempotency safeguard)
        content_stripped = content.rstrip()
        if content_stripped in companion_original_contents and not args.force:
            skipped_marker += 1
            if args.verbose:
                print(f"  [{i}] {lesson_id[:16]}... SKIP (companion already exists)")
            continue

        # Track stats
        if team_tag_missing:
            missing_team += 1
        if topic_tag_missing:
            missing_topic += 1
        if project_needs_fix:
            needs_project += 1

        if not team_tag_missing and not topic_tag_missing and not project_needs_fix:
            already_tagged += 1
            if args.verbose:
                print(f"  [{i}] {lesson_id[:16]}... OK (no changes needed, team={team})")
            continue

        # This lesson needs updates
        would_create += 1
        team_counts[team] = team_counts.get(team, 0) + 1

        # Build new tags (preserve original, add team + kodehold-learnings)
        new_tags = list(tags)
        if team_tag_missing:
            new_tags.append(team)
        if topic_tag_missing:
            new_tags.append("kodehold-learnings")
        new_tags.append(BATCH_MARKER)  # idempotency marker

        # Normalize project
        new_project = "kodehold" if project_needs_fix else project

        if args.verbose or args.dry_run:
            print(f"  [{i}] {lesson_id[:16]}...")
            print(f"        Content: {content[:80]}...")
            print(f"        Current tags: {tags}")
            print(f"        New tags:      {new_tags}")
            print(f"        Current project: {project}")
            print(f"        New project:      {new_project}")
            print(f"        Assigned team: {team}")
            print()

        if not args.dry_run:
            # Create companion lesson with unique content to ensure correct tags
            companion_content = content
            if not companion_content.endswith(f"[{BATCH_MARKER}]"):
                companion_content = companion_content.rstrip() + f"\n[{BATCH_MARKER}]"

            save_lesson(
                content=companion_content,
                tags=new_tags,
                project=new_project,
                verbose=args.verbose,
            )

    # Print stats
    print()
    print("=" * 60)
    print("STATISTICS")
    print("=" * 60)
    print(f"Total lessons:                 {total}")
    print(f"Missing team tag:              {missing_team}")
    print(f"Missing kodehold-learnings:    {missing_topic}")
    print(f"Needs project fix (CR1):       {needs_project}")
    print(f"Already correctly tagged:      {already_tagged}")
    print(f"Skipped (batch marker):        {skipped_marker}")
    print(f"Would create companions:       {would_create}")
    if would_create > 0:
        print()
        print("Team tag distribution (new companions):")
        for team in sorted(team_counts, key=lambda t: -team_counts[t]):
            print(f"  {team}: {team_counts[team]}")
    print()
    print(f"Mode: {'DRY RUN' if args.dry_run else 'APPLY'}")

    if args.dry_run:
        print()
        print("NOTE: Due to API limitation (auto-strengthen ignores tags on re-save),")
        print("companion lessons are created with unique content markers.")
        print("Original lessons remain intact. Run without --dry-run to apply.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
