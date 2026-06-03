# agentmemory Patches — v0.9.25

## Status: 1 ACTIVE PATCH

| Patch | Purpose |
|-------|---------|
| `agentmemory-viewer-bind-0.9.25.patch` | Bypass AGENTMEMORY_SECRET requirement for `AGENTMEMORY_VIEWER_HOST=0.0.0.0` |

## What It Does

Upstream **v0.9.25** added a security check in the viewer server: if the viewer host is
not a loopback address, the server requires **both** `AGENTMEMORY_SECRET` (for bearer
token validation) and `VIEWER_ALLOWED_HOSTS` (Host header allowlist).

In our dev environment, we want the viewer accessible on all interfaces
(`AGENTMEMORY_VIEWER_HOST=0.0.0.0`) without requiring `AGENTMEMORY_SECRET`. The patch
replaces the non-loopback check with `if (false)`, skipping the secret validation
entirely while keeping the `VIEWER_ALLOWED_HOSTS` allowlist intact.

## Apply

```bash
# Apply the dist patch:
sudo patch -p1 -d /usr/local/lib/node_modules/@agentmemory/agentmemory/dist \
  < patches/agentmemory-viewer-bind-0.9.25.patch

# Also patch index.mjs for consistency:
sudo sed -i 's/if (!isLoopbackHost(host)) {/if (false) {/' \
  /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/index.mjs

# Restart the service:
systemctl --user restart agentmemory
```

## Current .env Settings

```
AGENTMEMORY_VIEWER_HOST=0.0.0.0
VIEWER_ALLOWED_HOSTS="localhost,localhost:3113,127.0.0.1:3113,192.168.1.176:3113,am.server.int:3113"
```

`VIEWER_ALLOWED_HOSTS` is still respected by the Host header allowlist — the patch
**only** removes the `AGENTMEMORY_SECRET` requirement, not the host-based filtering.

## Historical Reference — v0.9.24 Archive

All patches that applied to v0.9.24 are preserved in `../patches-v0.9.24/`:

| File | Purpose | v0.9.25 resolution |
|------|---------|---------------------|
| `agentmemory-viewer-bind.patch` | Viewer bind `127.0.0.1` → `0.0.0.0` | Built into .env (`AGENTMEMORY_VIEWER_HOST=0.0.0.0`) |
| `agentmemory-triggervoid-to-trigger.patch` | `triggerVoid` → `trigger()` migration | Upstream PR #773 |
| `agentmemory-summary-xml-parse.patch` | XML markdown fence stripping (dead code ref) | Upstream PR #791 |
| `agentmemory-summary-xml-parse-src.patch` | Same fix for real runtime file | Upstream PR #791 |
| `agentmemory-capture-project-detection.patch` | Plugin reference (applied elsewhere) | See note below |
| `agentmemory-merged.patch` + `.bak` | Combined patch script (v0.9.24 only) | — |

## Other Local Modifications (Not Dist Patches)

- **Capture plugin project detection fix**: Applied directly to
  `~/.config/opencode/plugins/agentmemory-capture.ts`. Not a dist patch —
  it's a plugin modification that lives outside the agentmemory package.

## Post-Upgrade Verification

```bash
grep -o '"0\.9\.25"' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/version-*.mjs
# or check the running service:
systemctl --user status agentmemory
```

To verify the patch is active:

```bash
grep -n 'if (false)' /usr/local/lib/node_modules/@agentmemory/agentmemory/dist/index.mjs
# Expect: line(s) with "if (false) {"
```
