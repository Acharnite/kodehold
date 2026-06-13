#!/usr/bin/env bash
# detect-test-framework.sh — Detect test framework for a project
# Usage: scripts/detect-test-framework.sh [<project-root>]
# Output: <framework>:<command> on stdout
# Exit: 0 if detected, 1 if none found
set -euo pipefail

ROOT="${1:-.}"

# Priority 1: Cargo.toml
[ -f "$ROOT/Cargo.toml" ] && { echo "cargo:cargo test"; exit 0; }

# Priority 2: package.json with npm test script
if [ -f "$ROOT/package.json" ]; then
  if grep -q '"jest"' "$ROOT/package.json" 2>/dev/null; then
    echo "jest:npx jest"
    exit 0
  fi
  if grep -q '"vitest"' "$ROOT/package.json" 2>/dev/null; then
    echo "vitest:npx vitest run"
    exit 0
  fi
  if grep -q '"test"' <(grep -o '"scripts":{[^}]*}' "$ROOT/package.json" 2>/dev/null); then
    echo "npm:npm test"
    exit 0
  fi
fi

# Priority 4: Gemfile with rspec
[ -f "$ROOT/Gemfile" ] && grep -q "rspec" "$ROOT/Gemfile" 2>/dev/null && { echo "rspec:bundle exec rspec"; exit 0; }

# Priority 5: mix.exs
[ -f "$ROOT/mix.exs" ] && { echo "elixir:mix test"; exit 0; }

# Priority 6: Gradle
[ -f "$ROOT/build.gradle" -o -f "$ROOT/build.gradle.kts" ] && { echo "gradle:gradle test"; exit 0; }

# Priority 7: Maven
[ -f "$ROOT/pom.xml" ] && { echo "maven:mvn test"; exit 0; }

# Priority 8: SBT
[ -f "$ROOT/build.sbt" ] && { echo "sbt:sbt test"; exit 0; }

# Priority 9: Deno
[ -f "$ROOT/deno.json" -o -f "$ROOT/deno.jsonc" ] && { echo "deno:deno test"; exit 0; }

# Priority 10: Go
[ -f "$ROOT/go.mod" ] && { echo "go:go test ./..."; exit 0; }

# Priority 11: Makefile with test target (check for pytest passthrough)
if [ -f "$ROOT/Makefile" ] && grep -q '^test:' "$ROOT/Makefile" 2>/dev/null; then
  if grep -q "pytest" "$ROOT/Makefile" 2>/dev/null; then
    echo "pytest:make test  # detected pytest in Makefile"
    exit 0
  fi
  echo "make:make test"
  exit 0
fi

# Python checks: pyproject.toml with pytest config, setup.cfg, pytest.ini, or tests/*.py
if [ -f "$ROOT/pyproject.toml" ] && grep -q '\[tool.pytest.ini_options\]' "$ROOT/pyproject.toml" 2>/dev/null; then
  echo "pytest:pytest"
  exit 0
fi
if [ -f "$ROOT/setup.cfg" ] && grep -q '\[tool:pytest\]' "$ROOT/setup.cfg" 2>/dev/null; then
  echo "pytest:pytest"
  exit 0
fi
if [ -f "$ROOT/pytest.ini" ]; then
  echo "pytest:pytest"
  exit 0
fi
if ls "$ROOT/tests/"*.py 2>/dev/null | head -1 > /dev/null; then
  echo "pytest:pytest"
  exit 0
fi

# No framework detected
echo "No test framework detected" >&2
exit 1
