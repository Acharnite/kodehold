#!/usr/bin/env python3
"""agentmemory-session-cleanup.py — Engine for session cleanup."""
import json, os, sys
from datetime import datetime, timezone
from urllib.request import Request, urlopen

url = os.environ.get('AM_URL', 'http://localhost:3111')

def fetch_sessions(url):
    req = Request(f'{url}/agentmemory/sessions', method='GET')
    with urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read())
    return data.get('sessions', data if isinstance(data, list) else [])

sessions = fetch_sessions(url)
now = datetime.now(timezone.utc)
idle_min = float(os.environ.get('IDLE_MIN', '30'))
dry_run = os.environ.get('DRY_RUN', 'true') == 'true'

active = [s for s in sessions if s.get('status') == 'active']
stale = []

print(f"Active sessions:  {len(active)}")
print()

if not active:
    print("No active sessions found.")
    sys.exit(0)

# Header
print(f"{'Session ID':30} {'Idle':>6} {'Obs':>4}  Title")
print(f"{'-'*30} {'-'*6} {'-'*4}  {'-'*40}")

for s in sorted(active, key=lambda x: x.get('updatedAt') or x.get('startedAt', '')):
    sid = s.get('id', '?')
    updated = s.get('updatedAt') or s.get('startedAt', '')
    obs = s.get('observationCount', 0)
    title = (s.get('title') or '')[:40]
    if not updated:
        continue
    updated_dt = datetime.fromisoformat(updated.replace('Z', '+00:00'))
    idle_sec = (now - updated_dt).total_seconds()
    idle_actual = idle_sec / 60
    flag = " <-- STALE" if idle_actual >= idle_min else ""
    print(f"{sid[:25]:25} {idle_actual:5.0f}m {obs:3}  {title}{flag}")
    if idle_actual >= idle_min:
        stale.append(s)

print()
print(f"Total active:     {len(active)}")
print(f"Stale (>{idle_min:.0f}min idle): {len(stale)}")

if not stale:
    print("All sessions within threshold.")
    sys.exit(0)

if dry_run:
    print(f"Mode: DRY-RUN \u2014 would close {len(stale)} sessions")
    print("Run with --execute to actually close them")
else:
    closed = 0
    errors = 0
    for s in stale:
        sid = s.get('id', '?')
        try:
            body = json.dumps({'sessionId': sid}).encode('utf-8')
            req = Request(
                f'{url}/agentmemory/session/end',
                data=body,
                headers={'Content-Type': 'application/json'},
                method='POST'
            )
            resp = urlopen(req, timeout=10)
            result = json.loads(resp.read())
            if result.get('success') or result.get('status_code') == 200:
                print(f"  [OK] {sid[:25]}")
                closed += 1
            else:
                print(f"  [FAIL] {sid[:25]} \u2014 {result}")
                errors += 1
        except Exception as e:
            print(f"  [ERROR] {sid[:25]} \u2014 {e}")
            errors += 1
    print(f"\nClosed: {closed}, Errors: {errors}")
