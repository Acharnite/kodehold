#!/usr/bin/env python3
"""token-report.py — Generate self-contained HTML token usage report.

Queries OpenCode's local SQLite database and OpenRouter billing API,
producing a single self-contained HTML report at docs/dashboard/index.html.
"""

import argparse
import functools
import http.server
import json
import os
import signal
import sqlite3
import sys
import threading
import urllib.error
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone

# ── Paths ──────────────────────────────────────────────────────────────────────
DB_PATH = os.path.expanduser("~/.local/share/opencode/opencode.db")
OUTPUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs", "dashboard")
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "index.html")
ENV_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")


# ── Subscription Info ──────────────────────────────────────────────────
# opencode-go is billed as $60/month subscription. Costs shown are
# tracked usage, not additional billing.
OPENCODE_GO_SUBSCRIPTION_MONTHLY = 60.0


def _billing_period_start():
    """Return the start of the current opencode-go billing period (30th of month)."""
    today = datetime.now()
    year = today.year
    month = today.month
    # Billing period starts on the 30th
    if today.day >= 30:
        period_start = datetime(year, month, 30)
    else:
        # Go to previous month's 30th
        if month == 1:
            period_start = datetime(year - 1, 12, 30)
        else:
            period_start = datetime(year, month - 1, 30)
    return period_start.strftime("%Y-%m-%d")


def _billing_period_start_prev(period_start_str):
    """Return the start of the previous billing period given a period start date."""
    from datetime import timedelta
    ps = datetime.strptime(period_start_str, "%Y-%m-%d")
    # Go back ~30 days to find previous period start (previous month's 30th)
    if ps.month == 1:
        prev = datetime(ps.year - 1, 12, 30)
    else:
        prev = datetime(ps.year, ps.month - 1, 30)
    return prev.strftime("%Y-%m-%d")


def _billing_period_end():
    """Return the end of the current opencode-go billing period (30th of next month)."""
    today = datetime.now()
    year = today.year
    month = today.month
    if today.day >= 30:
        # Period ends next month's 30th
        if month == 12:
            period_end = datetime(year + 1, 1, 30)
        else:
            period_end = datetime(year, month + 1, 30)
    else:
        period_end = datetime(year, month, 30)
    return period_end.strftime("%Y-%m-%d")




def get_openrouter_api_key():
    """Read OPENROUTER_API_KEY from environment or .env file."""
    key = os.environ.get("OPENROUTER_API_KEY")
    if key:
        return key
    try:
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line.startswith("OPENROUTER_API_KEY="):
                    # Handle optional quotes
                    val = line.split("=", 1)[1].strip("\"'")
                    if val:
                        return val
    except FileNotFoundError:
        pass
    return None


def fetch_json(url, headers=None, timeout=10):
    """Fetch JSON from a URL with error handling."""
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, OSError) as e:
        return {"_error": str(e)}


def fetch_openrouter_credits(api_key):
    """Fetch total credits and usage from OpenRouter."""
    headers = {"Authorization": f"Bearer {api_key}"}
    data = fetch_json("https://openrouter.ai/api/v1/credits", headers=headers)
    return data


def fetch_openrouter_key_info(api_key):
    """Fetch key-specific usage info from OpenRouter."""
    headers = {"Authorization": f"Bearer {api_key}"}
    data = fetch_json("https://openrouter.ai/api/v1/auth/key", headers=headers)
    return data


def query_db(db, sql, params=None):
    """Execute SQL and return all rows as list of dicts."""
    try:
        cur = db.execute(sql, params or [])
        columns = [desc[0] for desc in cur.description]
        return [dict(zip(columns, row)) for row in cur.fetchall()]
    except sqlite3.OperationalError as e:
        # Table might not exist
        return {"_error": str(e)}


def connect_db():
    """Open database connection."""
    if not os.path.isfile(DB_PATH):
        return None
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.OperationalError:
        return None


def fmt_num(n):
    """Format large numbers with K/M/B suffix."""
    if n is None:
        return "0"
    try:
        n = float(n)
    except (ValueError, TypeError):
        return str(n)
    if n >= 1_000_000_000:
        return f"{n/1_000_000_000:.2f}B"
    if n >= 1_000_000:
        return f"{n/1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n/1_000:.1f}K"
    return f"{int(n)}"


def fmt_cost(n):
    """Format cost as $X.XX."""
    if n is None:
        return "$0.00"
    try:
        return f"${float(n):.2f}"
    except (ValueError, TypeError):
        return "$0.00"


def json_serialize(obj):
    """JSON serialize with safe defaults."""
    return json.dumps(obj, default=str)


# ── HTML Template ──────────────────────────────────────────────────────────────

def generate_html(data):
    """Generate complete HTML document as string."""
    db = data.get("db", {})
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    db_ok = "_error" not in db

    # Prepare chart data
    chart_data = _prepare_chart_data(db)

    # Render sections
    summary_html = _render_summary(db, ts)
    charts_html = _render_charts(chart_data)
    tables_html = _render_tables(db)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>KodeHold Token Report</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
  /* ── Reset & Base ── */
  *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
    background: #0f1117; color: #e1e4e8; line-height: 1.5;
    padding: 20px;
  }}
  .container {{ max-width: 1000px; margin: 0 auto; }}
  
  /* ── Header ── */
  .header {{ margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #30363d; }}
  .header h1 {{ font-size: 1.5rem; font-weight: 600; margin-bottom: 4px; }}
  .header .ts {{ color: #8b949e; font-size: 0.85rem; }}

  /* ── Summary Bar ── */
  .summary-bar {{
    display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 12px; margin-bottom: 28px;
  }}
  .summary-item {{
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: 14px 12px; text-align: center;
  }}
  .summary-item .value {{ font-size: 1.3rem; font-weight: 700; color: #58a6ff; }}
  .summary-item .label {{ font-size: 0.75rem; color: #8b949e; margin-top: 2px; text-transform: uppercase; letter-spacing: 0.5px; }}

  /* ── Chart Cards ── */
  .chart-card {{
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: 20px; margin-bottom: 20px;
  }}
  .chart-card h2 {{
    font-size: 1.05rem; font-weight: 600; margin-bottom: 12px;
    color: #f0f6fc;
  }}
  .chart-card .note {{
    font-size: 0.8rem; color: #8b949e; margin-top: 8px;
    font-style: italic;
  }}
  .chart-grid {{
    display: grid; grid-template-columns: 1fr 1fr;
    gap: 16px; margin-bottom: 20px;
  }}
  .chart-grid.single {{ grid-template-columns: 1fr; }}
  .chart-container {{ position: relative; height: 220px; }}
  .chart-container.tall {{ height: 300px; }}
  .chart-container.short {{ height: 180px; }}

  /* ── Tables ── */
  .table-card {{
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: 20px; margin-bottom: 20px; overflow-x: auto;
  }}
  .table-card h2 {{ font-size: 1.05rem; font-weight: 600; margin-bottom: 12px; color: #f0f6fc; }}
  table {{ width: 100%; border-collapse: collapse; font-size: 0.85rem; }}
  th, td {{ padding: 8px 10px; text-align: right; border-bottom: 1px solid #21262d; }}
  th {{ color: #8b949e; font-weight: 600; text-transform: uppercase; font-size: 0.7rem; letter-spacing: 0.5px; }}
  td {{ color: #e1e4e8; }}
  td:first-child, th:first-child {{ text-align: left; }}
  tr:hover td {{ background: #1c2128; }}

  /* ── OpenRouter Section ── */
  .or-card {{
    background: #161b22; border: 1px solid #30363d; border-radius: 8px;
    padding: 20px; margin-bottom: 20px;
  }}
  .or-card h2 {{ font-size: 1.05rem; font-weight: 600; margin-bottom: 12px; color: #f0f6fc; }}
  .progress-bar {{
    width: 100%; height: 24px; background: #21262d; border-radius: 12px;
    overflow: hidden; margin: 8px 0 12px;
  }}
  .progress-fill {{
    height: 100%; background: linear-gradient(90deg, #58a6ff, #3fb950);
    border-radius: 12px; transition: width 0.3s;
    display: flex; align-items: center; justify-content: center;
    font-size: 0.75rem; font-weight: 600; color: #fff; min-width: 40px;
  }}
  .or-stats {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 12px; }}
  .or-stat {{ padding: 8px; background: #0d1117; border-radius: 6px; }}
  .or-stat .val {{ font-weight: 600; color: #58a6ff; }}
  .or-stat .lbl {{ font-size: 0.7rem; color: #8b949e; text-transform: uppercase; }}
  .or-unavailable {{ color: #8b949e; font-style: italic; padding: 12px; background: #0d1117; border-radius: 6px; }}

  /* ── Empty State ── */
  .empty-state {{
    text-align: center; padding: 40px 20px; color: #8b949e;
  }}
  .empty-state h2 {{ font-size: 1.2rem; margin-bottom: 8px; color: #f0f6fc; }}

  /* ── Responsive ── */
  @media (max-width: 640px) {{
    .chart-grid {{ grid-template-columns: 1fr; }}
    .summary-bar {{ grid-template-columns: repeat(2, 1fr); }}
  }}
</style>
</head>
<body>
<div class="container">
  {summary_html}
  {charts_html}
  {tables_html}
</div>
<script>
  {_generate_chart_js(chart_data)}
</script>
</body>
</html>"""


def _prepare_chart_data(db, or_data=None):
    """Extract chart-ready data from query results."""
    daily = db.get("daily", [])
    per_model = db.get("per_model", [])
    per_provider = db.get("per_provider", [])

    # Daily trend data
    daily_dates = [r["day"] for r in daily]
    daily_cost = [float(r.get("daily_cost", 0) or 0) for r in daily]
    daily_input = [int(r.get("daily_input", 0) or 0) for r in daily]
    daily_output = [int(r.get("daily_output", 0) or 0) for r in daily]

    # Top models (top 10 by tokens) — exclude subscription models (opencode-go)
    non_sub_models = [r for r in per_model if r.get("provider") != "opencode-go"] if per_model else []
    models_sorted = sorted(non_sub_models, key=lambda r: int(r.get("input_tokens", 0) or 0) + int(r.get("output_tokens", 0) or 0), reverse=True)[:10]
    model_names = [r.get("model_name", "unknown") for r in models_sorted]
    model_tokens = [int(r.get("input_tokens", 0) or 0) + int(r.get("output_tokens", 0) or 0) for r in models_sorted]
    model_providers = [r.get("provider", "unknown") for r in models_sorted]

    # Providers for doughnut — exclude subscription (opencode-go), show sessions
    provider_names = [r.get("provider", "unknown") for r in per_provider if r.get("provider") != "opencode-go"]
    provider_sessions = [int(r.get("sessions", 0) or 0) for r in per_provider if r.get("provider") != "opencode-go"]

    # OpenRouter progress
    return {
        "daily_dates": daily_dates,
        "daily_cost": daily_cost,
        "daily_input": daily_input,
        "daily_output": daily_output,
        "model_names": model_names,
        "model_tokens": model_tokens,
        "model_providers": model_providers,
        "provider_names": provider_names,
        "provider_sessions": provider_sessions,
    }


def _render_summary(db, ts):
    """Render the header and summary bar."""
    totals = db.get("totals", {})
    if "_error" in db or not totals:
        return f"""
<div class="header">
  <h1>KodeHold Token Report</h1>
  <div class="ts">Generated: {ts}</div>
</div>
<div class="empty-state">
  <h2>No data available</h2>
  <p>No session data found in the OpenCode database.</p>
  <p style="margin-top:8px;font-size:0.85rem;">DB: {DB_PATH}</p>
</div>"""

    total_sessions = int(totals.get("total_sessions", 0) or 0)
    total_input = int(totals.get("total_input", 0) or 0)
    total_output = int(totals.get("total_output", 0) or 0)
    cache_hit_pct = float(totals.get("cache_hit_pct", 0) or 0)
    total_reasoning = int(totals.get("total_reasoning", 0) or 0)

    return f"""
<div class="header">
  <h1>KodeHold Token Usage</h1>
  <div class="ts">Generated: {ts}</div>
</div>
<div class="summary-bar">
  <div class="summary-item"><div class="value">{total_sessions}</div><div class="label">Sessions</div></div>
  <div class="summary-item"><div class="value">{fmt_num(total_input)}</div><div class="label">Input Tokens</div></div>
  <div class="summary-item"><div class="value">{fmt_num(total_output)}</div><div class="label">Output Tokens</div></div>
  <div class="summary-item"><div class="value">{fmt_num(total_reasoning)}</div><div class="label">Reasoning Tokens</div></div>
  <div class="summary-item"><div class="value">{cache_hit_pct}%</div><div class="label">Cache Hit Rate</div></div>
</div>"""
def _render_charts(cd):
    """Render chart card sections."""
    has_daily = len(cd["daily_dates"]) > 0
    has_models = len(cd["model_names"]) > 0
    has_providers = len(cd["provider_names"]) > 0

    html = ""

    if has_daily:
        html += f"""
<div class="chart-grid">
  <div class="chart-card">
    <h2>Daily Token Trend (Cost)</h2>
    <div class="chart-container"><canvas id="dailyCostChart"></canvas></div>
    <div class="note">{len(cd["daily_dates"])} days of data</div>
  </div>
  <div class="chart-card">
    <h2>Daily Token Volume</h2>
    <div class="chart-container"><canvas id="dailyTokenChart"></canvas></div>
    <div class="note">Input vs Output tokens per day</div>
  </div>
</div>"""
    else:
        html += """
<div class="chart-card">
  <h2>Trend Charts</h2>
  <div class="note">Not enough daily data to display trend charts. Start using OpenCode to generate session data.</div>
</div>"""

    if has_providers or has_models:
        html += '<div class="chart-grid'
        html += '">'

        if has_providers:
            html += f"""
  <div class="chart-card">
    <h2>Sessions by Provider</h2>
    <div class="chart-container"><canvas id="providerChart"></canvas></div>
  </div>"""

        if has_models:
            html += f"""
  <div class="chart-card">
    <h2>Tokens by Model (Top 10)</h2>
    <div class="chart-container tall"><canvas id="modelChart"></canvas></div>
  </div>"""

        html += "</div>"

    return html


def _render_tables(db):
    """Render data tables."""
    per_model = db.get("per_model", [])
    per_provider = db.get("per_provider", [])

    html = ""

    if per_model:
        rows = []
        for r in (per_model or []):
            is_sub = r.get("provider") == "opencode-go"
            prov_cell = r.get("provider", "?")
            if is_sub:
                prov_cell += ' <span class="sub-badge">(Subscription)</span>'
            cost_cell = '<span class="sub-badge">Subscription</span>' if is_sub else fmt_cost(r.get("total_cost", 0))
            rows.append(f"<tr><td>{r.get('model_name','?')}</td><td>{prov_cell}</td>"
                       f"<td>{cost_cell}</td><td>{fmt_num(r.get('input_tokens',0))}</td>"
                       f"<td>{fmt_num(r.get('output_tokens',0))}</td><td>{r.get('sessions',0)}</td></tr>")
        rows = "".join(rows)
        html += f"""
<div class="table-card">
  <h2>Per Model</h2>
  <table>
    <thead><tr><th>Model</th><th>Provider</th><th>Cost</th><th>Input Tokens</th><th>Output Tokens</th><th>Sessions</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</div>"""

    if per_provider:
        rows = []
        for r in per_provider:
            prov = r.get("provider", "?")
            is_sub = prov == "opencode-go"
            name_cell = prov
            if is_sub:
                name_cell += ' <span class="sub-badge">(Subscription)</span>'
            cost_cell = '<span class="sub-badge">Subscription</span>' if is_sub else fmt_cost(r.get("total_cost", 0))
            tokens_cell = fmt_num((r.get("input_tokens", 0) or 0) + (r.get("output_tokens", 0) or 0))
            sessions_cell = r.get("sessions", 0)
            rows.append(f"<tr><td>{name_cell}</td><td>{cost_cell}</td><td>{tokens_cell}</td><td>{sessions_cell}</td></tr>")
        rows = "".join(rows)
        html += f"""
<div class="table-card">
  <h2>Per Provider</h2>
  <table>
    <thead><tr><th>Provider</th><th>Cost</th><th>Tokens</th><th>Sessions</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</div>"""

    return html


def _generate_chart_js(cd):
    """Generate all Chart.js initialization code."""
    daily_dates_json = json_serialize(cd["daily_dates"])
    daily_cost_json = json_serialize(cd["daily_cost"])
    daily_input_json = json_serialize(cd["daily_input"])
    daily_output_json = json_serialize(cd["daily_output"])
    model_names_json = json_serialize(cd["model_names"])
    model_tokens_json = json_serialize(cd["model_tokens"])
    provider_names_json = json_serialize(cd["provider_names"])
    provider_sessions_json = json_serialize(cd["provider_sessions"])

    return f"""
document.addEventListener('DOMContentLoaded', function () {{
  // Color palette
  const colors = [
    '#58a6ff', '#3fb950', '#d29922', '#f85149', '#bc8cff',
    '#79c0ff', '#56d364', '#e3b341', '#ff7b72', '#d2a8ff',
    '#a5d6ff', '#7ee787', '#f0883e', '#ffa198', '#c9d1d9'
  ];

  Chart.defaults.color = '#8b949e';
  Chart.defaults.borderColor = '#30363d';

  // ── Daily Cost Chart ──
  const dailyCostData = {daily_cost_json};
  const dailyDates = {daily_dates_json};
  if (document.getElementById('dailyCostChart') && dailyCostData.length > 0) {{
    new Chart('dailyCostChart', {{
      type: 'line',
      data: {{
        labels: dailyDates,
        datasets: [{{
          label: 'Cost ($)',
          data: dailyCostData,
          borderColor: '#58a6ff',
          backgroundColor: 'rgba(88, 166, 255, 0.1)',
          fill: true,
          tension: 0.3,
          pointRadius: 3,
          pointHoverRadius: 5,
        }}]
      }},
      options: {{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {{ legend: {{ display: false }} }},
        scales: {{
          x: {{ ticks: {{ maxTicksLimit: 10, font: {{ size: 10 }} }} }},
          y: {{ beginAtZero: true, ticks: {{ callback: v => '$' + v.toFixed(2) }} }}
        }}
      }}
    }});
  }}

  // ── Daily Token Chart ──
  const dailyInput = {daily_input_json};
  const dailyOutput = {daily_output_json};
  if (document.getElementById('dailyTokenChart') && dailyInput.length > 0) {{
    new Chart('dailyTokenChart', {{
      type: 'bar',
      data: {{
        labels: dailyDates,
        datasets: [
          {{ label: 'Input Tokens', data: dailyInput, backgroundColor: 'rgba(88, 166, 255, 0.7)', borderRadius: 2 }},
          {{ label: 'Output Tokens', data: dailyOutput, backgroundColor: 'rgba(188, 140, 255, 0.7)', borderRadius: 2 }}
        ]
      }},
      options: {{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {{ legend: {{ position: 'top', labels: {{ boxWidth: 12, font: {{ size: 10 }} }} }} }},
        scales: {{
          x: {{ ticks: {{ maxTicksLimit: 8, font: {{ size: 10 }} }} }},
          y: {{ beginAtZero: true, ticks: {{ callback: v => v.toLocaleString() }} }}
        }}
      }}
    }});
  }}

  // ── Provider Doughnut (by Sessions) ──
  const providerNames = {provider_names_json};
  const providerSessions = {provider_sessions_json};
  if (document.getElementById('providerChart') && providerNames.length > 0) {{
    new Chart('providerChart', {{
      type: 'doughnut',
      data: {{
        labels: providerNames,
        datasets: [{{
          data: providerSessions,
          backgroundColor: colors.slice(0, providerNames.length),
          borderWidth: 1,
        }}]
      }},
      options: {{
        responsive: true,
        maintainAspectRatio: false,
        plugins: {{
          legend: {{ position: 'right', labels: {{ boxWidth: 12, font: {{ size: 10 }} }} }},
          tooltip: {{ callbacks: {{ label: ctx => ctx.label + ': ' + ctx.parsed.toLocaleString() + ' sessions' }} }}
        }}
      }}
    }});
  }}

  // ── Model Horizontal Bar (by Tokens) ──
  const modelNames = {model_names_json};
  const modelTokens = {model_tokens_json};
  if (document.getElementById('modelChart') && modelNames.length > 0) {{
    new Chart('modelChart', {{
      type: 'bar',
      data: {{
        labels: modelNames,
        datasets: [{{
          label: 'Tokens',
          data: modelTokens,
          backgroundColor: modelNames.map((_, i) => colors[i % colors.length]),
          borderRadius: 3,
        }}]
      }},
      options: {{
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {{ legend: {{ display: false }} }},
        scales: {{
          x: {{ beginAtZero: true, ticks: {{ callback: v => v.toLocaleString() }} }},
          y: {{ ticks: {{ font: {{ size: 9 }} }} }}
        }}
      }}
    }});
  }}
}});

"""


# ── Data Collection ────────────────────────────────────────────────────────────

def collect_db_data():
    """Query the SQLite database for all report data."""
    conn = connect_db()
    if conn is None:
        return {"_error": f"Database not found at {DB_PATH}"}

    try:
        totals = query_db(conn, """
            SELECT
                ROUND(SUM(s.cost), 2) AS total_cost,
                COALESCE(SUM(s.tokens_input), 0) AS total_input,
                COALESCE(SUM(s.tokens_output), 0) AS total_output,
                COALESCE(SUM(s.tokens_reasoning), 0) AS total_reasoning,
                COALESCE(SUM(s.tokens_cache_read), 0) AS cache_read,
                COALESCE(SUM(s.tokens_cache_write), 0) AS cache_write,
                COUNT(*) AS total_sessions,
                ROUND(COALESCE(SUM(s.tokens_cache_read), 0) * 100.0 /
                    NULLIF(COALESCE(SUM(s.tokens_input + s.tokens_cache_read), 0), 0), 1) AS cache_hit_pct
            FROM session s
        """)

        daily = query_db(conn, """
            SELECT
                DATE(s.time_created / 1000, 'unixepoch') AS day,
                ROUND(SUM(s.cost), 2) AS daily_cost,
                COALESCE(SUM(s.tokens_input), 0) AS daily_input,
                COALESCE(SUM(s.tokens_output), 0) AS daily_output,
                COUNT(*) AS daily_sessions
            FROM session s
            WHERE s.time_created IS NOT NULL AND s.time_created > 0
            GROUP BY day
            HAVING day IS NOT NULL
            ORDER BY day
        """)

        per_model = query_db(conn, """
            SELECT
                json_extract(s.model, '$.id') AS model_name,
                json_extract(s.model, '$.providerID') AS provider,
                ROUND(SUM(s.cost), 4) AS total_cost,
                COALESCE(SUM(s.tokens_input), 0) AS input_tokens,
                COALESCE(SUM(s.tokens_output), 0) AS output_tokens,
                COUNT(*) AS sessions
            FROM session s
            WHERE s.model IS NOT NULL AND s.model != ''
            GROUP BY model_name, provider
            ORDER BY total_cost DESC
        """)

        per_provider = query_db(conn, """
            SELECT
                json_extract(s.model, '$.providerID') AS provider,
                ROUND(SUM(s.cost), 2) AS total_cost,
                COALESCE(SUM(s.tokens_input), 0) AS input_tokens,
                COALESCE(SUM(s.tokens_output), 0) AS output_tokens,
                COUNT(*) AS sessions
            FROM session s
            WHERE s.model IS NOT NULL AND s.model != ''
            GROUP BY provider
            ORDER BY total_cost DESC
        """)

        # Get OpenRouter models used
        or_models_raw = query_db(conn, """
            SELECT DISTINCT json_extract(s.model, '$.id') AS model_name
            FROM session s
            WHERE json_extract(s.model, '$.providerID') = 'openrouter'
                AND s.model IS NOT NULL AND s.model != ''
            ORDER BY model_name
        """)

        # Get total cost for OpenRouter-provider sessions
        or_cost_raw = query_db(conn, """
            SELECT ROUND(SUM(s.cost), 4) AS or_cost
            FROM session s
            WHERE json_extract(s.model, '$.providerID') = 'openrouter'
        """)

        # Get opencode-go cost for CURRENT billing period only (subscription resets 30th)
        period_start = _billing_period_start()
        period_end = _billing_period_end()
        # Convert to numeric timestamps (ms) to avoid strftime escaping issues
        ps_dt = datetime.strptime(period_start, "%Y-%m-%d")
        ps_ts = int(ps_dt.timestamp() * 1000)
        prev_start = _billing_period_start_prev(period_start)
        prev_dt = datetime.strptime(prev_start, "%Y-%m-%d")
        prev_ts = int(prev_dt.timestamp() * 1000)
        ps_end = datetime.strptime(period_end, "%Y-%m-%d")
        ps_end_ts = int(ps_end.timestamp() * 1000)

        ocg_alltime_raw = query_db(conn, """
            SELECT ROUND(SUM(s.cost), 2) AS ocg_cost
            FROM session s
            WHERE json_extract(s.model, '$.providerID') = 'opencode-go'
        """)
        ocg_current_raw = query_db(conn, f"""
            SELECT ROUND(SUM(s.cost), 2) AS ocg_cost,
                   COUNT(*) AS sessions,
                   COALESCE(SUM(s.tokens_input + s.tokens_output), 0) AS tokens
            FROM session s
            WHERE json_extract(s.model, '$.providerID') = 'opencode-go'
              AND s.time_created >= {ps_ts}
        """)
        ocg_prev_raw = query_db(conn, f"""
            SELECT ROUND(SUM(s.cost), 2) AS ocg_cost,
                   COUNT(*) AS sessions,
                   COALESCE(SUM(s.tokens_input + s.tokens_output), 0) AS tokens
            FROM session s
            WHERE json_extract(s.model, '$.providerID') = 'opencode-go'
              AND s.time_created >= {prev_ts}
              AND s.time_created < {ps_ts}
        """)

        ocg_alltime_cost = float(ocg_alltime_raw[0]["ocg_cost"] or 0) if ocg_alltime_raw else 0
        ocg_current_cost = float(ocg_current_raw[0]["ocg_cost"] or 0) if ocg_current_raw else 0
        ocg_current_sessions = int(ocg_current_raw[0]["sessions"] or 0) if ocg_current_raw else 0
        ocg_current_tokens = int(ocg_current_raw[0]["tokens"] or 0) if ocg_current_raw else 0
        ocg_prev_cost = float(ocg_prev_raw[0]["ocg_cost"] or 0) if ocg_prev_raw else 0
        ocg_prev_sessions = int(ocg_prev_raw[0]["sessions"] or 0) if ocg_prev_raw else 0
        ocg_prev_tokens = int(ocg_prev_raw[0]["tokens"] or 0) if ocg_prev_raw else 0


        # Filter out free entries (local LLMs, unused models)
        per_model = [r for r in (per_model or []) if float(r.get("total_cost", 0) or 0) > 0]
        per_provider = [r for r in (per_provider or []) if float(r.get("total_cost", 0) or 0) > 0]

        return {
            "totals": totals[0] if totals else {},
            "daily": daily if daily else [],
            "per_model": per_model if per_model else [],
            "per_provider": per_provider if per_provider else [],
            "or_models": [r.get("model_name", "") for r in (or_models_raw or []) if r.get("model_name")],
            "or_cost": float(or_cost_raw[0]["or_cost"] or 0) if or_cost_raw else 0,
            "ocg_current_cost": ocg_current_cost,
            "ocg_current_sessions": ocg_current_sessions,
            "ocg_current_tokens": ocg_current_tokens,
            "ocg_alltime_cost": ocg_alltime_cost,
            "ocg_prev_cost": ocg_prev_cost,
            "ocg_prev_sessions": ocg_prev_sessions,
            "ocg_prev_tokens": ocg_prev_tokens,
            "period_start": period_start,
            "period_end": period_end,
            "subscription_monthly": OPENCODE_GO_SUBSCRIPTION_MONTHLY,
        }

    except sqlite3.Error as e:
        return {"_error": str(e)}
    finally:
        conn.close()


# ── Serve Mode ────────────────────────────────────────────────────────────────

class _SilentHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler that suppresses default request logging."""

    def log_message(self, format, *args):
        pass


def _generate_and_report():
    """Run full data collection + HTML generation, write to disk, return summaries."""
    db_data = collect_db_data()

    data = {
        "db": db_data,
    }
    html = generate_html(data)

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        f.write(html)

    return db_data


def _print_refresh_summary(db_data):
    """Print a one-line refresh summary."""
    totals = db_data.get("totals", {})
    if "_error" not in db_data and totals:
        total_sessions = int(totals.get("total_sessions", 0) or 0)
        total_input = int(totals.get("total_input", 0) or 0)
        total_output = int(totals.get("total_output", 0) or 0)
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] Report regenerated ({total_sessions} sessions, "
              f"{fmt_num(total_input)} in / {fmt_num(total_output)} out)")
    else:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] Report regenerated (no data)")


def run_serve(host, port, refresh):
    """Run the headless webserver mode."""
    from http.server import HTTPServer

    # Generate on startup
    print(f"Token Report Server running at http://{host}:{port}")
    print(f"Auto-refresh every {refresh} seconds")

    db_data = _generate_and_report()
    _print_refresh_summary(db_data)

    # Stop event for background thread
    stop_event = threading.Event()

    # Background refresh thread
    def refresh_worker():
        while not stop_event.wait(refresh):
            db_data = _generate_and_report()
            _print_refresh_summary(db_data)

    refresher = threading.Thread(target=refresh_worker, daemon=True)
    refresher.start()

    # HTTP server
    handler = functools.partial(_SilentHandler, directory=OUTPUT_DIR)
    server = HTTPServer((host, port), handler)

    # Graceful shutdown on SIGINT/SIGTERM
    def shutdown_handler(sig, frame):
        print("\nShutting down...")
        stop_event.set()
        server.server_close()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        stop_event.set()
        server.server_close()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Generate KodeHold token usage report.")
    parser.add_argument("--serve", action="store_true", help="Start HTTP server to serve the report")
    parser.add_argument("--port", type=int, default=8080, help="Port for HTTP server (default: 8080)")
    parser.add_argument("--refresh", type=int, default=60, help="Auto-refresh interval in seconds (default: 60)")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind HTTP server (default: 0.0.0.0)")
    args = parser.parse_args()

    if args.serve:
        return run_serve(args.host, args.port, args.refresh)

    # Step 1: Collect DB data
    db_data = collect_db_data()

    # Step 2: Fetch OpenRouter data
    or_data = {"credits": {}, "key_info": {}, "models": db_data.get("or_models", []), "db_or_cost": db_data.get("or_cost", 0)}
    api_key = get_openrouter_api_key()
    if api_key:
        or_data["credits"] = fetch_openrouter_credits(api_key)
        or_data["key_info"] = fetch_openrouter_key_info(api_key)
    else:
        or_data["credits"] = {"_error": "OPENROUTER_API_KEY not found in environment or .env file"}
        or_data["key_info"] = {"_error": "OPENROUTER_API_KEY not found"}

    # Step 3: Build the full data payload
    data = {
        "db": db_data,
        "openrouter": or_data,
    }

    # Step 4: Generate HTML
    html = generate_html(data)

    # Step 5: Write output
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        f.write(html)

    # Summary
    totals = db_data.get("totals", {})
    if "_error" not in db_data and totals:
        total_sessions = int(totals.get("total_sessions", 0) or 0)
        total_input = int(totals.get("total_input", 0) or 0)
        total_output = int(totals.get("total_output", 0) or 0)
        print(f"Report generated: {OUTPUT_FILE}")
        print(f"  Sessions: {total_sessions}  |  {fmt_num(total_input)} in / {fmt_num(total_output)} out")
    elif "_error" in db_data:
        print(f"Report generated: {OUTPUT_FILE}")
        print(f"  Note: {db_data['_error']}")
    else:
        print(f"Report generated: {OUTPUT_FILE}")
        print("  No session data found.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
