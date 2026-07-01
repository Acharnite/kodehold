#!/usr/bin/env bash
# ADR numbering consistency checks
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 1. No duplicate ADR numbers in filenames
dups=$(ls "$SCRIPT_DIR/docs/adr/ADR-"*.md | grep -oP 'ADR-\K\d{4}[a-z]?' | sort | uniq -d || true)
if [ -z "$dups" ]; then
  pass "No duplicate ADR numbers in filenames"
else
  echo "$dups" | while read -r num; do
    echo "    Duplicate ADR-$num files:"
    ls "$SCRIPT_DIR/docs/adr/ADR-$num-"*.md 2>/dev/null | sed 's/^/      /'
  done
  fail "Duplicate ADR numbers found in filenames"
fi

# 2. No duplicate ADR numbers in index (from link text only)
index_dups=$(grep -oP '\bADR-\K\d{4}[a-z]?(?=\])' "$SCRIPT_DIR/docs/adr/README.md" | sort | uniq -d || true)
if [ -z "$index_dups" ]; then
  pass "No duplicate ADR numbers in index"
else
  echo "$index_dups" | while read -r num; do
    echo "    ADR-$num appears multiple times in index"
  done
  fail "Duplicate ADR numbers found in index"
fi

# 3. Every ADR file in index exists on disk
ADR_DIR="$SCRIPT_DIR/docs/adr"
rm -f "$ADR_DIR/.test_missing"
grep -oP '\(\K[^)]+\.md(?=\))' "$SCRIPT_DIR/docs/adr/README.md" | while read -r fname; do
  fname="${fname#../}"
  [ -f "$ADR_DIR/$fname" ] || { echo "$fname" >> "$ADR_DIR/.test_missing"; }
done
if [ ! -f "$ADR_DIR/.test_missing" ]; then
  pass "All ADR index entries have matching files"
else
  echo "    Missing files:"
  cat "$ADR_DIR/.test_missing" | sed 's/^/      /'
  rm -f "$ADR_DIR/.test_missing"
  fail "ADR index entries missing files"
fi
rm -f "$ADR_DIR/.test_missing"

# 4. Every ADR file is in the index
indexed=$(grep -oP '\bADR-\d{4}[a-z]?-[^)]+\.md' "$SCRIPT_DIR/docs/adr/README.md" | sort -u)
missing=0
for f in "$SCRIPT_DIR/docs/adr/ADR-"*.md; do
  fb=$(basename "$f")
  grep -qF "$fb" <<< "$indexed" && pass "File in index: $fb" || { echo "    MISSING: $fb"; missing=$((missing+1)); }
done
[ "$missing" -eq 0 ] && pass "All ADR files are in index" || fail "$missing ADR files missing from index"

# 5. Sequential ADR numbering
numbers=$(ls "$SCRIPT_DIR/docs/adr/ADR-"*.md | grep -oP 'ADR-\K\d{4}' | sort -n -u)
prev=0; gaps=0
while IFS= read -r n; do
  if [ "$prev" -ne 0 ] && [ $((10#$n - 10#$prev)) -gt 1 ]; then
    for ((g = prev + 1; g < n; g++)); do
      printf -v gs "%04d" "$g"
      echo "    Gap: ADR-$gs (between ADR-$(printf '%04d' $prev) and ADR-$(printf '%04d' $n))"
    done
    gaps=1
  fi
  prev=$n
done <<< "$numbers"
[ "$gaps" -eq 0 ] && pass "ADR numbers are sequential" || fail "ADR numbering gaps found"
