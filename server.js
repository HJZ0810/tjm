/*!
 * 个人工作台 —— 公开服务骨架
 *
 * 仅基于 Node.js 标准库，零第三方依赖。
 * 本文件提供可独立运行的最小服务：健康检查与静态资源托管；
 * 业务路由、鉴权与 WebSocket 等能力在私有完整版中实现，不在公开范围。
 * 配置优先级：环境变量 > 默认值。
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const PUBLIC_DIR = path.join(__dirname, 'public');
const VERSION = (() => {
  try { return require('./package.json').version; } catch { return '0.0.0'; }
})();

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.woff2': 'font/woff2'
};

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  res.end(body);
}

function serveStatic(req, res, pathname) {
  let rel = decodeURIComponent(pathname);
  if (rel === '/') rel = '/index.html';
  const filePath = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!filePath.startsWith(PUBLIC_DIR)) {
    return sendJson(res, 403, { ok: false, error: 'forbidden' });
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      return sendJson(res, 404, { ok: false, error: 'not found' });
    }
    res.writeHead(200, {
      'Content-Type': MIME_TYPES[path.extname(filePath)] || 'application/octet-stream'
    });
    res.end(data);
  });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/health') {
    return sendJson(res, 200, {
      ok: true,
      status: 'running',
      version: VERSION,
      time: new Date().toISOString()
    });
  }
  if (req.method === 'GET' || req.method === 'HEAD') {
    return serveStatic(req, res, url.pathname);
  }
  sendJson(res, 405, { ok: false, error: 'method not allowed' });
});

server.listen(PORT, HOST, () => {
  console.log(`[workbench] framework listening on http://${HOST}:${PORT} (v${VERSION})`);
});

module.exports = server;
