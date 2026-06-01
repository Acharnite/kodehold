#!/usr/bin/env bash
# KodeHold Token Dashboard — query and display token usage metrics
set -euo pipefail

# ── Colors & helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
PROJECT_PATH="$(pwd)"
LIMIT=50
JSON_MODE=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AM_URL="http://localhost:3111"

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [--project <path>] [--limit <N>] [--json] [--help]

--project <path>   Project path (default: current directory)
--limit <N>        Number of historical entries to query (default: 50)
--json             Output raw JSON instead of formatted table
--help             Show this help

KodeHold Token Dashboard — displays per-team token usage vs budgets.
Requires: scripts/token-usage.sh and agentmemory REST API (port 3111).
EOF
  exit 0
}

# ── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)   PROJECT_PATH="$2"; shift 2 ;;
    --limit)     LIMIT="$2"; shift 2 ;;
    --json)      JSON_MODE=true; shift ;;
    --help|-h)   usage ;;
    *)           echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ── Resolve project name from path (for token-usage.sh) ──────────────────────
PROJECT_NAME="$(basename "$PROJECT_PATH" | tr -cd '[:alnum:]-')"
[ -z "$PROJECT_NAME" ] && PROJECT_NAME="kodehold"

# ── Timestamp ─────────────────────────────────────────────────────────────────
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "unknown")

# ── Validate prerequisites ───────────────────────────────────────────────────
TOKEN_USAGE_SCRIPT="${SCRIPT_DIR}/token-usage.sh"
if [ ! -f "$TOKEN_USAGE_SCRIPT" ]; then
  echo "Error: $TOKEN_USAGE_SCRIPT not found" >&2
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo "Error: curl is required" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required" >&2
  exit 1
fi

# ── Step 1: Get current session data from token-usage.sh ─────────────────────
CURRENT_JSON="{}"
if CURRENT_RAW=$("$TOKEN_USAGE_SCRIPT" --project "$PROJECT_NAME" --minutes 60 2>/dev/null); then
  # Parse the JSON array/object into a normalized teams map via Python
  CURRENT_JSON=$(echo "$CURRENT_RAW" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print(json.dumps({"teams":{}, "total":0, "window_minutes":60}))
    sys.exit(0)

teams = {}
total = 0
if isinstance(data, list):
    for entry in data:
        agent = entry.get("agent", "unknown")
        tokens = entry.get("total_tokens", 0)
        teams[agent] = tokens
        total += tokens
elif isinstance(data, dict):
    if "teams" in data:
        teams = data["teams"]
        total = data.get("total", sum(teams.values()))
    else:
        teams = {k: v for k, v in data.items() if k != "window_minutes"}
        total = sum(v for v in teams.values() if isinstance(v, (int, float)))

print(json.dumps({"teams": teams, "total": total, "window_minutes": 60}))
' 2>/dev/null) || CURRENT_JSON='{"teams":{},"total":0,"window_minutes":60}'
else
  echo "Warning: token-usage.sh failed — no current session data" >&2
  CURRENT_JSON='{"teams":{},"total":0,"window_minutes":60}'
fi

# ── Step 2: Query historical data from agentmemory ───────────────────────────
HISTORICAL_JSON="[]"

if ! curl -sf "$AM_URL/agentmemory/health" >/dev/null 2>&1; then
  echo "Error: Agentmemory not available — run 'iii start' first" >&2
  exit 1
fi

SEARCH_RESULT=$(curl -s -X POST "$AM_URL/agentmemory/search" \
  -H "Content-Type: application/json" \
  -d "{\"query\":\"token-usage\",\"limit\":$LIMIT,\"project\":\"$PROJECT_PATH\"}" 2>/dev/null || echo '{}')

HISTORICAL_JSON=$(echo "$SEARCH_RESULT" | python3 -c '
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    print(json.dumps([]))
    sys.exit(0)

results = []
if isinstance(data, dict):
    for key in ["observations", "results", "memories", "data"]:
        if key in data and isinstance(data[key], list):
            results = data[key]
            break
elif isinstance(data, list):
    results = data

metrics = []
for r in results:
    content = r.get("content", r.get("text", ""))
    if isinstance(content, str):
        try:
            obj = json.loads(content)
            if isinstance(obj, dict) and "tokens" in obj and "team" in obj:
                metrics.append(obj)
        except Exception:
            pass
    elif isinstance(content, dict) and "tokens" in content:
        metrics.append(content)

print(json.dumps(metrics))
' 2>/dev/null) || HISTORICAL_JSON="[]"

# ── Check for no historical data ─────────────────────────────────────────────
NO_HISTORICAL=false
if [ "$(echo "$HISTORICAL_JSON" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)" = "0" ]; then
  NO_HISTORICAL=true
  echo "Note: No historical token data found. Run a few sessions first." >&2
fi

# ── Pass env vars for Python computation ─────────────────────────────────────
export KH_PROJECT_PATH="$PROJECT_PATH"
export KH_LIMIT="$LIMIT"
export KH_TIMESTAMP="$TIMESTAMP"
export KH_HISTORICAL="$HISTORICAL_JSON"

# ── Step 3: Compute dashboard data ───────────────────────────────────────────
DASHBOARD_JSON=$(echo "$CURRENT_JSON" | python3 -c '
import sys, json, os
from collections import defaultdict

current = json.load(sys.stdin)
project_path = os.environ.get("KH_PROJECT_PATH", "/")
limit = int(os.environ.get("KH_LIMIT", "50"))
ts = os.environ.get("KH_TIMESTAMP", "")
historical = json.loads(os.environ.get("KH_HISTORICAL", "[]"))

teams_current = current.get("teams", {})
total_current = current.get("total", sum(teams_current.values()))

# Phase
phase = os.environ.get("KODEHOLD_PHASE", "")
if not phase:
    try:
        with open(os.path.join(project_path, ".kodehold-state")) as f:
            for line in f:
                if line.startswith("STATE="):
                    phase = line.split("=")[1].strip()
                    break
    except (FileNotFoundError, IOError):
        phase = "ACTIVE"

# Aggregate historical data
team_entries = defaultdict(list)
for entry in historical:
    team = entry.get("team", "")
    if team:
        team_entries[team].append(entry)

for team in team_entries:
    team_entries[team].sort(key=lambda e: e.get("timestamp", ""))

team_previous = {}
team_7d_avg = {}
all_teams = sorted(set(list(teams_current.keys()) + list(team_entries.keys())))

for team in all_teams:
    entries = team_entries.get(team, [])
    if len(entries) >= 2:
        team_previous[team] = entries[-2].get("tokens", 0)
    else:
        team_previous[team] = 0
    if entries:
        team_7d_avg[team] = round(sum(e.get("tokens", 0) for e in entries) / len(entries))
    else:
        team_7d_avg[team] = 0

total_previous = sum(team_previous.values())
total_7d_avg = sum(team_7d_avg.values())

# Budgets
BUDGETS = {
    "engineers": 12000, "architects": 8000, "scribes": 4000,
    "reviewers": 8000, "testers": 8000, "fls": 8000,
    "second-opinion": 6000, "director": 8000, "build": 8000,
    "explore": 8000, "general": 8000,
}

warnings_list = []
total_budget_k = 0
light_mode = os.environ.get("KODEHOLD_LIGHT", "") == "1"

for team in all_teams:
    cur = teams_current.get(team, 0)
    budget_k = BUDGETS.get(team, 8000)
    total_budget_k += budget_k
    pct = (cur / (budget_k * 1000)) * 100 if budget_k > 0 else 0

    if pct > 100:
        warnings_list.append(f"{team} at {pct:.0f}% of budget ({budget_k:,}k)")
    elif pct >= 80:
        warnings_list.append(f"{team} approaching budget at {pct:.0f}% ({budget_k:,}k)")

overall_status = "ok"
if warnings_list:
    pcts = []
    for w in warnings_list:
        try:
            pcts.append(float(w.split("at ")[1].split("%")[0]))
        except (IndexError, ValueError):
            pass
    if any(p > 100 for p in pcts):
        overall_status = "over"
    else:
        overall_status = "warning"

result = {
    "timestamp": ts,
    "project": project_path,
    "phase": phase,
    "current": teams_current,
    "previous": team_previous,
    "trends": team_7d_avg,
    "warnings": warnings_list,
    "status": overall_status,
    "total_current": total_current,
    "total_previous": total_previous,
    "total_7d_avg": total_7d_avg,
    "total_budget_k": total_budget_k,
    "light_mode": light_mode
}

print(json.dumps(result))
' 2>/dev/null) || {
  echo "Error: Failed to compute dashboard data" >&2
  exit 1
}

# ── Determine exit code ──────────────────────────────────────────────────────
HAS_CURRENT=$(echo "$CURRENT_JSON" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("1" if d.get("teams") and sum(d["teams"].values()) > 0 else "0")' 2>/dev/null || echo "0")
HAS_HISTORICAL=$(echo "$HISTORICAL_JSON" | python3 -c 'import sys,json; print("1" if len(json.load(sys.stdin)) > 0 else "0")' 2>/dev/null || echo "0")
EXIT_CODE=0
if [ "$HAS_CURRENT" = "0" ] && [ "$HAS_HISTORICAL" = "0" ]; then
  EXIT_CODE=2
fi

# ── Step 4: Output ────────────────────────────────────────────────────────────
if [ "$JSON_MODE" = true ]; then
  echo "$DASHBOARD_JSON"
  exit "$EXIT_CODE"
fi

# ── Table mode — format the dashboard display ────────────────────────────────
echo "$DASHBOARD_JSON" | python3 -c '
import sys, json

d = json.load(sys.stdin)
teams = d.get("current", {})
previous = d.get("previous", {})
trends = d.get("trends", {})
warnings = d.get("warnings", [])
phase = d.get("phase", "ACTIVE")
project = d.get("project", "")
total_cur = d.get("total_current", sum(teams.values()))
total_prev = d.get("total_previous", 0)
total_7d = d.get("total_7d_avg", 0)
total_budget_k = d.get("total_budget_k", 0)
light_mode = d.get("light_mode", False)
ts = d.get("timestamp", "")

BUDGETS = {
    "engineers": 12000, "architects": 8000, "scribes": 4000,
    "reviewers": 8000, "testers": 8000, "fls": 8000,
    "second-opinion": 6000, "director": 8000, "build": 8000,
    "explore": 8000, "general": 8000,
}

def fmt(n):
    if n >= 1_000_000_000:
        return f"{n/1_000_000_000:.1f}B"
    elif n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n/1_000:.1f}K"
    else:
        return str(n)

def status_pct(cur, bk):
    return (cur / (bk * 1000)) * 100 if bk > 0 else 0

# ── Build lines ──
lines = []
lines.append("")
sep1 = "\u2501" * 62
sep2 = "\u2500" * 62
arrow = "\u0394"
bullet = "\u2022"
check = "\u2705"
warn_sym = "\u26a1"
green_circle = "\U0001f7e2"
yellow_circle = "\U0001f7e1"
red_circle = "\U0001f534"

lines.append(f"KodeHold Token Dashboard \u2014 {ts}")
lines.append(sep1)
lines.append(f"  Project: {project}  |  Phase: {phase}")
lines.append(sep2)

# Header
hdr = "  {:<18} {:>10} {:>10} {:>10} {:>8}  {:>10}".format("Team", "Tokens", arrow + " prev", "7d avg", "Budget", "Status")
lines.append(hdr)
lines.append(sep2)

# Team rows
sorted_teams = sorted(teams.keys())
for team in sorted_teams:
    cur = teams[team]
    prev = previous.get(team, 0)
    avg7 = trends.get(team, 0)
    delta = cur - prev
    bk = BUDGETS.get(team, 8000)

    if delta > 0:
        ds = f"+{fmt(delta)}"
    elif delta < 0:
        ds = f"-{fmt(abs(delta))}"
    else:
        ds = "0"

    pct = status_pct(cur, bk)
    if pct > 100:
        st = f"{red_circle} {pct:.0f}%"
    elif pct >= 80:
        st = f"{yellow_circle} {pct:.0f}%"
    else:
        st = f"{green_circle} OK"

    lines.append(f"  {team:<18} {fmt(cur):>10} {ds:>10} {fmt(avg7):>10} {bk:>6,}k  {st:>10}")

# Separator + total
lines.append(sep2)

total_delta = total_cur - total_prev
if total_delta > 0:
    tds = f"+{fmt(total_delta)}"
elif total_delta < 0:
    tds = f"-{fmt(abs(total_delta))}"
else:
    tds = "0"

tbd = f"{total_budget_k:,}k"
if light_mode:
    tbd += "*"

tpct = status_pct(total_cur, total_budget_k)
if tpct > 100:
    tst = f"{red_circle} Over"
elif tpct >= 80:
    tst = f"{yellow_circle} Warning"
else:
    tst = f"{green_circle} OK"

lines.append("  {:<18} {:>10} {:>10} {:>10} {:>8}  {:>10}".format("Total", fmt(total_cur), tds, fmt(total_7d), tbd, tst))
lines.append(sep1)

# Warnings / All OK
if warnings:
    lines.append("")
    lines.append(f"{warn_sym}  Warnings:")
    for w in warnings:
        lines.append(f"    {bullet} {w}")
    if light_mode:
        lines.append("")
        lines.append("  * Light mode budget (KODEHOLD_LIGHT=1)")
else:
    lines.append("")
    lines.append(f"{check}  All teams within budget")

lines.append("")

print("\n".join(lines))
'
exit "$EXIT_CODE"
