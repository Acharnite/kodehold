#!/usr/bin/env bash
# Integration: FLS Agent Workflow & Triage
# Tests that .opencode/agents/fls.md correctly defines:
#   1. Triage criteria (minor vs major)
#   2. Minor fix workflow and major escalation workflow
#   3. State awareness restrictions per lifecycle state
#   4. Reference to state-awareness skill
#   5. Reference to investigate skill for unclear root cause
#   6. ICM documentation requirements
#   7. Frontmatter permission: skill: allow
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

FLS=".opencode/agents/fls.md"
[ -f "$FLS" ] || fail "fls.md not found at $FLS"

echo "--- Integration: FLS Workflow ---"

# ──────────────────────────────────────────────
# Test 1: Triage criteria parsing
# ──────────────────────────────────────────────
echo "  [1/7] Triage criteria (minor vs major)"

# Minor criteria (each should appear as a distinct concept)
for criterion in "Typo fixes" "label changes" "CSS/UI tweaks" "clear root cause" "low blast radius" "Configuration value" "Error message" "Single-file" "no schema impact"; do
  grep -qi "$criterion" "$FLS" \
    && pass "minor criterion: '$criterion'" \
    || fail "minor criterion '$criterion' not found in fls.md"
done

# Major criteria
for criterion in "multiple files" "modules" "Schema" "data model" "New feature" "Security" "Performance regression" "Architectural" "Uncertain root cause"; do
  grep -qi "$criterion" "$FLS" \
    && pass "major criterion: '$criterion'" \
    || fail "major criterion '$criterion' not found in fls.md"
done

# Verify minor/major sections are labeled
grep -q "### Minor (fix directly)" "$FLS" \
  && pass "minor section header present" \
  || fail "minor section header '### Minor (fix directly)' missing"

grep -q "### Major (escalate" "$FLS" \
  && pass "major section header present" \
  || fail "major section header '### Major (escalate' missing"

# ──────────────────────────────────────────────
# Test 2: Workflow documentation
# ──────────────────────────────────────────────
echo "  [2/7] Workflow documentation"

# Minor fix flow steps (triage -> investigate -> fix -> verify -> document)
for step in "Triage" "Project discovery" "investigate" "Implement" "Verify" "Document"; do
  grep -qi "$step" "$FLS" \
    && pass "minor flow step: '$step'" \
    || fail "minor flow step '$step' not found in fls.md"
done

# Major escalation flow
grep -q "ESCALATE:" "$FLS" \
  && pass "major escalation: ESCALATE: prefix present" \
  || fail "major escalation missing 'ESCALATE:' prefix"

grep -q "Impact assessment" "$FLS" \
  && pass "major escalation: impact assessment present" \
  || fail "major escalation missing 'impact assessment'"

grep -q "REOPEN" "$FLS" \
  && pass "major escalation: REOPEN referenced" \
  || fail "major escalation missing REOPEN reference"

# ──────────────────────────────────────────────
# Test 3: State awareness restrictions per lifecycle state
# ──────────────────────────────────────────────
echo "  [3/7] State awareness restrictions"

# Each state must have documented restrictions
for state in "CLOSED" "ACTIVE" "REVIEW" "INIT" "REOPEN"; do
  grep -q "$state" "$FLS" \
    && pass "state '$state' addressed in FLS state table" \
    || fail "state '$state' not mentioned in FLS state restrictions"
done

# Specific restrictions
grep -q "CLOSED.*Minor hotfix" "$FLS" \
  && pass "CLOSED: minor hotfixes only" \
  || fail "CLOSED: missing 'minor hotfixes only' restriction"

grep -q "ACTIVE.*Minor fixes" "$FLS" \
  && pass "ACTIVE: minor fixes allowed" \
  || fail "ACTIVE: missing 'minor fixes' allowance"

grep -q "REVIEW.*Bug fixes only" "$FLS" \
  && pass "REVIEW: bug fixes only" \
  || fail "REVIEW: missing 'bug fixes only' restriction"

grep -q "INIT.*Do not work" "$FLS" \
  && pass "INIT/REOPEN: do not work directly" \
  || fail "INIT/REOPEN: missing 'do not work directly' restriction"

# ──────────────────────────────────────────────
# Test 4: State-awareness skill reference
# ──────────────────────────────────────────────
echo "  [4/7] State awareness skill reference"

grep -q "state-awareness/SKILL.md" "$FLS" \
  && pass "state-awareness skill referenced" \
  || fail "missing reference to '.opencode/skills/state-awareness/SKILL.md'"

# Verify the referenced skill file actually exists
[ -f ".opencode/skills/state-awareness/SKILL.md" ] \
  && pass "state-awareness skill file exists" \
  || fail "state-awareness skill file does not exist at .opencode/skills/state-awareness/SKILL.md"

# ──────────────────────────────────────────────
# Test 5: Investigate skill reference for unclear root cause
# ──────────────────────────────────────────────
echo "  [5/7] Investigate skill reference"

grep -q "investigate/SKILL.md" "$FLS" \
  && pass "investigate skill referenced" \
  || fail "missing reference to '.opencode/skills/investigate/SKILL.md'"

# Verify the referenced skill file actually exists
[ -f ".opencode/skills/investigate/SKILL.md" ] \
  && pass "investigate skill file exists" \
  || fail "investigate skill file does not exist at .opencode/skills/investigate/SKILL.md"

# Verify it's linked to unclear root cause (the trigger condition)
grep -q "root cause is unclear" "$FLS" \
  && pass "investigate skill tied to unclear root cause" \
  || fail "investigate skill not linked to 'root cause is unclear' condition"

# ──────────────────────────────────────────────
# Test 6: ICM documentation requirement
# ──────────────────────────────────────────────
echo "  [6/7] ICM documentation requirements"

# FLS routes ICM storage through Director → Scribes (per ADR-0010)
# Verify FLS mentions Scribes in context of ICM documentation
grep -qi "ICM.*Scribes\|Scribes.*ICM\|ICM storage via Scribes" "$FLS" \
  && pass "ICM routing through Scribes documented" \
  || fail "missing ICM routing through Scribes in FLS workflow"

# Verify FLS mentions Director in context of ICM/documentation
grep -qi "Director.*ICM\|ICM.*Director\|Director.*Scribes\|Scribes.*Director" "$FLS" \
  && pass "Director → Scribes ICM flow documented" \
  || fail "missing Director → Scribes ICM flow in FLS workflow"

# Verify documentation is mentioned in responsibilities
grep -q "Document" "$FLS" \
  && pass "documentation mentioned in responsibilities" \
  || fail "documentation not mentioned in FLS responsibilities"

# ──────────────────────────────────────────────
# Test 7: Frontmatter permissions — skill: allow
# ──────────────────────────────────────────────
echo "  [7/7] Frontmatter skill permission"

# Extract frontmatter (between --- markers)
fm=$(sed -n '1,/^---$/p' "$FLS" | sed '1d;$d')

echo "$fm" | grep -q "^permission:" \
  && pass "frontmatter has permission block" \
  || fail "frontmatter missing 'permission:' key"

echo "$fm" | grep -q "skill: allow" \
  && pass "permission includes 'skill: allow' (needed to load investigate skill)" \
  || fail "frontmatter missing 'skill: allow' - FLS cannot load investigate skill"

# Verify the skill: allow is under the permission block (indentation check)
grep -A10 "^permission:" "$FLS" | grep -q "skill:" \
  && pass "skill permission is within permission block" \
  || fail "skill: allow not under permission block in frontmatter"

echo "--- Integration: All FLS workflow checks passed ---"
