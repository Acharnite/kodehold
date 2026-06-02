# KodeHold Custom Viewer

Custom web viewer for agentmemory's REST API — adds Frontier, Routines, Signals, and Actions tabs with project filtering.

## Usage

Open `index.html` in a browser while agentmemory is running on port 3111.

### URL Parameters
- `?port=3111` — set custom API port (default: 3111)

### CORS

If you see a CORS error, the viewer cannot reach the agentmemory API. Options:
1. Set `AGENTMEMORY_CORS=true` in agentmemory's .env file and restart
2. Use a reverse proxy (nginx/Caddy) to serve both on the same origin
3. Open with: `chromium --disable-web-security --user-data-dir=/tmp/am-viewer`

### Tabs
- **Frontier** — Unblocked actions sorted by score
- **Routines** — Registered routine templates with step DAG
- **Signals** — Threaded inter-agent messages
- **Actions** — All actions with project filter

## ADR

See [ADR-0035](../../docs/adr/ADR-0035-custom-kodehold-viewer.md) for the full design.
