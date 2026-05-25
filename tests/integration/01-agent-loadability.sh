#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

echo "--- Integration: Agent File Loadability ---"

# Each agent file must parse: frontmatter + content body
for f in .opencode/agents/*.md; do
  name=$(basename "$f" .md)

  # Extract frontmatter (between --- markers)
  fm=$(sed -n '1,/^---$/p' "$f" | sed '1d;$d')
  body=$(sed -n '/^---$/,$p' "$f" | sed '1,2d')

  [ -z "$fm" ] && fail "$name: empty frontmatter"
  [ -z "$body" ] && fail "$name: empty body"

  # Parse YAML frontmatter basics
  echo "$fm" | grep -q "^name:" || fail "$name: missing name in frontmatter"
  echo "$fm" | grep -q "^mode:" || fail "$name: missing mode in frontmatter"
  echo "$fm" | grep -q "^permission:" || fail "$name: missing permission in frontmatter"

  pass "$name: parseable (${#body} chars body)"
done

echo "--- Integration: All agent files loadable ---"
