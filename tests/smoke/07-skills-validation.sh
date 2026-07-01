#!/usr/bin/env bash
# Phase 5 — Skills validation across agent files, design doc, and disk
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# ── 1. Extract skills referenced in agent files ───────────────────
agent_skills=$(
  grep -rhoP '\.opencode/skills/\K[^/]+' "$SCRIPT_DIR/.opencode/agents/" 2>/dev/null \
  | sort -u
)

if [ -z "$agent_skills" ]; then
  fail "No skill references found in .opencode/agents/*.md"
else
  pass "Skills referenced in agent files:"
  echo "$agent_skills" | while read -r s; do echo "    - $s"; done
fi

# ── 2. Verify each referenced skill exists on disk ────────────────
missing_skills=0
while IFS= read -r skill; do
  if [ -f "$SCRIPT_DIR/.opencode/skills/$skill/SKILL.md" ]; then
    pass "Skill on disk: $skill"
  else
    echo "    MISSING: .opencode/skills/$skill/SKILL.md"
    missing_skills=$((missing_skills + 1))
  fi
done <<< "$agent_skills"

if [ "$missing_skills" -eq 0 ]; then
  pass "All agent-referenced skills exist on disk"
else
  fail "$missing_skills agent-referenced skills missing from disk"
fi

# ── 3. Design doc §7.4 skills table vs actual disk state ────────
design_section=$(
  sed -n '/^### 7\.4 Skills System/,/^### /p' "$SCRIPT_DIR/docs/design/README.md" 2>/dev/null || true
)
if [ -z "$design_section" ]; then
  fail "Could not find §7.4 Skills System in design doc"
else
  design_skills=$(echo "$design_section" \
    | grep '^| *\`' \
    | sed -n 's/^| *`\([^`]*\)`.*/\1/p' \
    | sort -u)

  if [ -z "$design_skills" ]; then
    fail "No skills found in §7.4 table"
  else
    pass "Skills listed in design doc §7.4:"
    echo "$design_skills" | while read -r s; do echo "    - $s"; done
  fi

  design_missing=0
  while IFS= read -r skill; do
    if [ -f "$SCRIPT_DIR/.opencode/skills/$skill/SKILL.md" ]; then
      pass "Design doc skill on disk: $skill"
    else
      echo "    DESIGN DOC references skill not on disk: $skill"
      design_missing=$((design_missing + 1))
    fi
  done <<< "$design_skills"

  if [ "$design_missing" -eq 0 ]; then
    pass "All design doc skills exist on disk"
  else
    fail "$design_missing design doc skills missing from disk"
  fi
fi

# ── 4. .opencode/skills/README.md lists all actual skills ───────
disk_skills=$(find "$SCRIPT_DIR/.opencode/skills" -maxdepth 2 -name 'SKILL.md' \
  | sed 's|/SKILL\.md$||' \
  | xargs -n1 basename \
  | sort -u)

readme_listed=$(
  sed -n '/^## Available Skills/,/^## /p' "$SCRIPT_DIR/.opencode/skills/README.md" 2>/dev/null \
  | grep '^| \[' \
  | sed -n 's/^| \[\([^]]*\)\](.*/\1/p' \
  | sort -u
)

readme_dir_list=$(
  sed -n '/^## Structure/,/^## /p' "$SCRIPT_DIR/.opencode/skills/README.md" 2>/dev/null \
  | grep -oP '`\K[^`]+(?=/SKILL\.md`)' \
  | sort -u
)

all_readme_skills=$(printf "%s\n%s" "$readme_listed" "$readme_dir_list" | sort -u)

unlisted_skills=0
while IFS= read -r skill; do
  if echo "$all_readme_skills" | grep -qx "$skill"; then
    pass "README lists: $skill"
  else
    echo "    UNLISTED: $skill (exists on disk but not in README)"
    unlisted_skills=$((unlisted_skills + 1))
  fi
done <<< "$disk_skills"

phantom_skills=0
while IFS= read -r skill; do
  if [ -f "$SCRIPT_DIR/.opencode/skills/$skill/SKILL.md" ]; then
    :
  elif [ "$skill" = "opencode-rag" ]; then
    :
  else
    echo "    PHANTOM: $skill (in README but no SKILL.md on disk)"
    phantom_skills=$((phantom_skills + 1))
  fi
done <<< "$all_readme_skills"

if [ "$unlisted_skills" -eq 0 ]; then
  pass "All disk skills are documented in README"
else
  fail "$unlisted_skills skills on disk not listed in README"
fi

if [ "$phantom_skills" -eq 0 ]; then
  pass "No phantom skills in README"
else
  fail "$phantom_skills phantom skills in README (not on disk)"
fi
