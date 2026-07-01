#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

AGENTS=".opencode/agents"
[ -d "$AGENTS" ] || fail "agents directory not found at $AGENTS"

echo ""
echo "━━━ Agent Content Tests ━━━"
echo ""

# Test 1: director.md has delegation protocol
DIRECTOR="$AGENTS/director.md"
[ -f "$DIRECTOR" ] || fail "director.md not found"

grep -qi "Delegation Protocol\|Delegation Flow" "$DIRECTOR" \
  && pass "director.md: delegation protocol present" \
  || fail "director.md: missing delegation protocol"

grep -qi "Triage-Check Protocol" "$DIRECTOR" \
  && pass "director.md: triage-check protocol present" \
  || fail "director.md: missing triage-check protocol"

for state in "INIT" "ACTIVE" "REVIEW" "CLOSED" "REOPEN"; do
  grep -q "$state" "$DIRECTOR" \
    && pass "director.md: lifecycle state '$state'" \
    || fail "director.md: missing lifecycle state '$state'"
done

grep -qi "gate validation\|validate transition\|Gatekeeper" "$DIRECTOR" \
  && pass "director.md: gate validation flow present" \
  || fail "director.md: missing gate validation flow"

grep -qi "Token Budget\|token budget" "$DIRECTOR" \
  && pass "director.md: token budget protocol present" \
  || fail "director.md: missing token budget protocol"

grep -qi "Context Window Pressure\|context.*pressure" "$DIRECTOR" \
  && pass "director.md: context window pressure protocol present" \
  || fail "director.md: missing context window pressure protocol"

# Test 2: architects.md has design workflow
ARCHITECTS="$AGENTS/architects.md"
[ -f "$ARCHITECTS" ] || fail "architects.md not found"

grep -qi "Design Document\|ADR\|Nygard" "$ARCHITECTS" \
  && pass "architects.md: design/ADR workflow present" \
  || fail "architects.md: missing design/ADR workflow"

grep -qi "technology\|trade-offs" "$ARCHITECTS" \
  && pass "architects.md: technology evaluation documented" \
  || fail "architects.md: missing technology evaluation"

# Test 3: engineers.md has implementation workflow
ENGINEERS="$AGENTS/engineers.md"
[ -f "$ENGINEERS" ] || fail "engineers.md not found"

grep -qi "The Ladder\|ADR-0049\|YAGNI\|standard library" "$ENGINEERS" \
  && pass "engineers.md: The Ladder (ADR-0049) present" \
  || fail "engineers.md: missing The Ladder (ADR-0049)"

grep -qi "design doc\|design document" "$ENGINEERS" \
  && pass "engineers.md: references design document" \
  || fail "engineers.md: missing design document reference"

grep -qi "Never write tests\|Testers.*role\|never write tests" "$ENGINEERS" \
  && pass "engineers.md: test boundary defined" \
  || fail "engineers.md: missing test boundary"

# Test 4: reviewers.md has review workflow
REVIEWERS="$AGENTS/reviewers.md"
[ -f "$REVIEWERS" ] || fail "reviewers.md not found"

grep -qi "Review Checklist\|code matches design\|verify.*implementation" "$REVIEWERS" \
  && pass "reviewers.md: code review against design doc" \
  || fail "reviewers.md: missing code review against design doc"

grep -qi "ADR compliance\|ADR-0049\|ADR-0048" "$REVIEWERS" \
  && pass "reviewers.md: ADR compliance check" \
  || fail "reviewers.md: missing ADR compliance check"

grep -qi "gate validation\|validate.*transition\|Gatekeeper\|ADR-0017" "$REVIEWERS" \
  && pass "reviewers.md: gate validation present" \
  || fail "reviewers.md: missing gate validation"

grep -qi "Second opinion\|second.opinion\|cross.model" "$REVIEWERS" \
  && pass "reviewers.md: second opinion coordination" \
  || fail "reviewers.md: missing second opinion coordination"

# Test 5: testers.md has testing workflow
TESTERS="$AGENTS/testers.md"
[ -f "$TESTERS" ] || fail "testers.md not found"

grep -qi "Testing Strategy\|testing strategy\|design doc" "$TESTERS" \
  && pass "testers.md: test strategy reference" \
  || fail "testers.md: missing test strategy reference"

grep -qi "regression\|Regression" "$TESTERS" \
  && pass "testers.md: regression testing" \
  || fail "testers.md: missing regression testing"

grep -qi "edge case\|boundary\|Edge Case" "$TESTERS" \
  && pass "testers.md: edge case analysis" \
  || fail "testers.md: missing edge case analysis"

grep -qi "coverage\|Coverage" "$TESTERS" \
  && pass "testers.md: coverage reporting" \
  || fail "testers.md: missing coverage reporting"

# Test 6: scribes.md has documentation workflow
SCRIBES="$AGENTS/scribes.md"
[ -f "$SCRIBES" ] || fail "scribes.md not found"

grep -qi "Documentation\|design doc\|README" "$SCRIBES" \
  && pass "scribes.md: documentation workflow" \
  || fail "scribes.md: missing documentation workflow"

grep -qi "CHANGES.md\|changelog\|Changelog" "$SCRIBES" \
  && pass "scribes.md: changelog management" \
  || fail "scribes.md: missing changelog management"

grep -qi "ADR status\|ADR lifecycle\|ADR" "$SCRIBES" \
  && pass "scribes.md: ADR management" \
  || fail "scribes.md: missing ADR management"

grep -qi ".opencode/memory\|memory\|knowledge.*storage" "$SCRIBES" \
  && pass "scribes.md: memory storage" \
  || fail "scribes.md: missing memory storage"

# Test 7: second-opinion.md has review protocol
SECOND="$AGENTS/second-opinion.md"
[ -f "$SECOND" ] || fail "second-opinion.md not found"

grep -qi "different model\|different AI\|cross.provider\|cross-provider" "$SECOND" \
  && pass "second-opinion.md: cross-model validation" \
  || fail "second-opinion.md: missing cross-model validation"

grep -qi "proceed.*revise.*redesign\|Recommendation.*proceed\|Recommendation.*revise\|Recommendation.*redesign" "$SECOND" \
  && pass "second-opinion.md: recommendation pattern" \
  || fail "second-opinion.md: missing recommendation pattern"

grep -qi "read.only\|read.*only\|no.*write" "$SECOND" \
  && pass "second-opinion.md: read-only access documented" \
  || fail "second-opinion.md: missing read-only access constraint"

# # Test 8: FLS workflow (noted as already validated in 04-fls-workflow.sh)
[ -f "$AGENTS/fls.md" ] && pass "fls.md exists (validated in 04-fls-workflow.sh)" \
  || fail "fls.md not found"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}All agent content tests pass${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
