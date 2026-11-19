// A dependency-free static server for a build folder (Story 1.13 D8): the web smoke starts it as
// Playwright's webServer, and the laptop views a server build through an SSH tunnel to it
// (docs/build.md). Serves BUILD_DIR on 127.0.0.1 only, so /web/… and /web_debug/… are reachable.
//   BUILD_DIR=builds/<version> PORT=8060 node tools/web_smoke/serve.js
// No COOP/COEP headers: a single-threaded build needs none (Godot's shell checks only WebGL2,
// Fetch and a secure context, and 127.0.0.1 / a tunnelled localhost is secure).
// Why not `python3 -m http.server`: it doesn't know .pck, and a second runtime adds nothing.
'use strict';

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

// .wasm must be application/wasm, or the browser can't compile it while it streams in.
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
};

const root = process.env.BUILD_DIR ? path.resolve(process.env.BUILD_DIR) : '';
const port = Number(process.env.PORT || 8060);

function stat(file) {
  try {
    return fs.statSync(file, { throwIfNoEntry: false }) || null;
  } catch {
    return null; // a NUL byte or another path the OS refuses
  }
}

if (!root || !stat(root)?.isDirectory()) {
  console.error('serve.js: set BUILD_DIR to a build folder, e.g. BUILD_DIR=builds/<version> node tools/web_smoke/serve.js');
  process.exit(1);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { Allow: 'GET, HEAD' }).end();
    return;
  }
  // The query string goes first: /web_debug/index.html?room=perf_worst is index.html.
  let rel;
  try {
    rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  } catch {
    res.writeHead(400).end();
    return;
  }
  let file = path.join(root, rel);
  // An encoded ../ survives URL parsing and is decoded above; never serve outside BUILD_DIR.
  if (file !== root && !file.startsWith(root + path.sep)) {
    res.writeHead(404).end();
    return;
  }
  let st = stat(file);
  if (st?.isDirectory()) {
    file = path.join(file, 'index.html');
    st = stat(file);
  }
  if (!st?.isFile()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream',
    'Content-Length': st.size,
    'Cache-Control': 'no-store', // a rebuilt build at the same path must never come from the cache
  });
  if (req.method === 'HEAD') {
    res.end();
    return;
  }
  fs.createReadStream(file).on('error', () => res.destroy()).pipe(res);
});

server.on('error', (e) => {
  console.error(`serve.js: ${e.message}`);
  process.exit(1);
});
server.listen(port, '127.0.0.1', () => {
  console.log(`serve.js: ${root} on http://127.0.0.1:${port}/ (web/index.html, web_debug/index.html)`);
});
