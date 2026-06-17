import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VIEWER_DIR = __dirname;
const KODEHOLD_ROOT = path.resolve(__dirname, '../..');
const AM_HOST = '127.0.0.1';
const AM_PORT = 3111;
const BIND_PORT = 3115;
const BIND_HOST = '0.0.0.0';

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.js':   'application/javascript; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.svg':  'image/svg+xml',
  '.png':  'image/png',
  '.ico':  'image/x-icon',
  '.md':   'text/markdown; charset=utf-8',
};

function serveStatic(res, filePath) {
  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found: ' + path.basename(filePath));
      return;
    }
    res.writeHead(200, {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache',
    });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // Proxy API calls
  if (url.pathname.startsWith('/agentmemory/')) {
    const opts = {
      hostname: AM_HOST,
      port: AM_PORT,
      path: url.pathname + url.search,
      method: req.method,
      headers: { ...req.headers, host: AM_HOST + ':' + AM_PORT }
    };

    const proxy = http.request(opts, (proxyRes) => {
      res.writeHead(proxyRes.statusCode, {
        ...proxyRes.headers,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
      });
      proxyRes.pipe(res);
    });

    proxy.on('error', () => {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'agentmemory unreachable' }));
    });

    req.pipe(proxy);
    return;
  }

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    });
    res.end();
    return;
  }

  // Serve ADR files from root or workspace docs/adr/
  const adrMatch = url.pathname.match(/^\/adr\/(?:(bob|lib-validate|qbit-migrate|radarr-lang-router|deepresearch)\/)?(ADR-.+\.md)$/);
  if (adrMatch) {
    const project = adrMatch[1];
    const fileName = adrMatch[2];
    let adrDir;
    if (project) {
      adrDir = path.join(KODEHOLD_ROOT, 'workspaces', project, 'docs', 'adr');
    } else {
      adrDir = path.join(KODEHOLD_ROOT, 'docs', 'adr');
    }
    // Try exact filename first, then glob for filename starting with the ADR ID
    const exactPath = path.join(adrDir, fileName);
    if (fs.existsSync(exactPath)) {
      serveStatic(res, exactPath);
      return;
    }
    // Fallback: find first file in adrDir that starts with the ADR ID
    const adrId = fileName.replace(/\.md$/, '');
    try {
      const files = fs.readdirSync(adrDir);
      const match = files.find(f => f.startsWith(adrId) && f.endsWith('.md') && !f.endsWith('.original.md'));
      if (match) {
        serveStatic(res, path.join(adrDir, match));
        return;
      }
    } catch (_) {}
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('ADR not found: ' + fileName);
    return;
  }

  // Serve static files from VIEWER_DIR
  let requestPath = url.pathname;
  if (requestPath === '/' || requestPath === '') {
    requestPath = '/index.html';
  }
  // Strip leading slash for safe join
  const safePath = requestPath.replace(/^\/+/, '');
  const filePath = path.join(VIEWER_DIR, safePath);

  // Prevent directory traversal
  if (!filePath.startsWith(VIEWER_DIR)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  serveStatic(res, filePath);
});

server.listen(BIND_PORT, BIND_HOST, () => {
  console.log(`KodeHold custom viewer at http://${BIND_HOST}:${BIND_PORT}`);
  console.log(`  Serving: ${VIEWER_DIR}`);
  console.log(`  Agentmemory API proxy: http://${AM_HOST}:${AM_PORT}`);
});
