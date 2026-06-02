import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const VIEWER_FILE = path.join(__dirname, 'index.html');
const AM_HOST = '127.0.0.1';
const AM_PORT = 3111;
const BIND_PORT = 3115;
const BIND_HOST = '0.0.0.0';

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
      // Add CORS headers for flexibility
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

  // Serve custom viewer
  fs.readFile(VIEWER_FILE, 'utf-8', (err, data) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Failed to load viewer: ' + err.message);
      return;
    }
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(data);
  });
});

server.listen(BIND_PORT, BIND_HOST, () => {
  console.log(`KodeHold custom viewer at http://${BIND_HOST}:${BIND_PORT}`);
});
