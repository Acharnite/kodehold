# FLS Hotfix: agentmemory WebSocket Port 3113 Binding

## Date: 2026-05-31

## Symptom
WebSocket connection to `ws://192.168.1.176:3113/` fails — connection refused.

## Root Cause
agentmemory viewer server hardcodes `server.listen(port, "127.0.0.1")` in the bundled
source, binding the viewer/WebSocket endpoint (port 3113 = REST port + 2) to loopback only.

## Fix Applied
1. Patched `server.listen(currentPort, "127.0.0.1")` → `"0.0.0.0"` in:
   - `/usr/local/lib/node_modules/@agentmemory/agentmemory/dist/src-B8J9Exum.mjs` (line 14119)
   - `/usr/local/lib/node_modules/@agentmemory/agentmemory/dist/index.mjs` (line 14608)
2. Stopped & disabled `agentmemory-socat.service` (workaround no longer needed)
3. Removed `Wants=agentmemory-socat.service` from `agentmemory.service`

## Verification
- `ss -tlnp` shows `0.0.0.0:3113` (was `127.0.0.1:3113`)
- `curl http://127.0.0.1:3113/` → HTTP 200
- No socat on port 3114
- No fallback port — viewer started on 3113 directly

## Note
Patch is in `/usr/local/lib/node_modules/` — will be overwritten by `npm install -g @agentmemory/agentmemory` upgrade.

## Automated Re-apply

A patch script survives npm upgrades:

```bash
bash scripts/patch-agentmemory.sh
```

This patches both files via `sed` and reports status. Run it after:

```bash
npm install -g @agentmemory/agentmemory
bash scripts/patch-agentmemory.sh
systemctl --user restart agentmemory
```

## Critical Finding (2026-06-02)

The agentmemory CLI (`/usr/local/bin/agentmemory` → `cli.mjs`) imports
**`src-B8J9Exum.mjs` at runtime**, NOT `index.mjs`. The `index.mjs` file is
effectively dead code. Both files exist in the dist directory with duplicated
code from the bundler, but only `src-B8J9Exum.mjs` is loaded by the running
service.

**Impact:** Patches targeting only `index.mjs` have NO EFFECT. All patch
scripts and the merged patch (`patches/agentmemory-merged.patch`) now target
both files, or specifically `src-B8J9Exum.mjs`.

See `patches/README.md` for the full file map and patch guide.

### Files
- **Script:** `scripts/patch-agentmemory.sh` — apply/reapply the viewer-bind fix
- **Patch:** `patches/agentmemory-viewer-bind.patch` — reference diff (for documentation)
- **Patch:** `patches/agentmemory-summary-xml-parse-src.patch` — summary XML fix (REAL target)
- **Merged:** `patches/agentmemory-merged.patch` — ALL patches in one script
- **Docs:** `patches/README.md` — file architecture map
