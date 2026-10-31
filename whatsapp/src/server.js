// HTTP API of the bridge (contracts/adapter_api.yaml): GET /health, POST /send. Port 8004.
// `transport` is anything with { isConnected(): bool, detail(): string, deliver(plan): Promise }.
// Tests pass a fake transport, so this file has no Baileys import.

import http from 'node:http';

import { replyToPlan, validateReply } from './logic.js';

const MAX_BODY = 1_000_000;

function sendJson(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) });
  res.end(data);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error('too_large'));
        req.destroy();
      } else chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

export function createServer({ transport, log = console }) {
  return http.createServer(async (req, res) => {
    const path = (req.url ?? '/').split('?')[0];
    try {
      if (req.method === 'GET' && path === '/health') {
        const connected = Boolean(transport.isConnected());
        return sendJson(res, 200, { status: connected ? 'ok' : 'degraded', connected, detail: transport.detail() });
      }

      if (req.method === 'POST' && path === '/send') {
        let body;
        try {
          body = JSON.parse(await readBody(req));
        } catch {
          return sendJson(res, 422, { code: 'validation_error', message: 'body must be JSON (OutgoingReply)' });
        }
        const errors = validateReply(body);
        if (errors.length) {
          return sendJson(res, 422, { code: 'validation_error', message: errors[0], details: { errors } });
        }
        if (!transport.isConnected()) {
          return sendJson(res, 503, { code: 'unavailable', message: 'WhatsApp session not connected' });
        }
        try {
          await transport.deliver(replyToPlan(body));
        } catch (err) {
          log.error?.({ message_id: body.id, err: err.message }, 'send failed');
          return sendJson(res, 503, { code: 'unavailable', message: 'WhatsApp send failed' });
        }
        return sendJson(res, 202, { status: 'sent', message_id: body.id });
      }

      return sendJson(res, 404, { code: 'not_found', message: 'not found' });
    } catch (err) {
      log.error?.({ err: err.message }, 'request failed');
      return sendJson(res, 500, { code: 'internal_error', message: 'internal error' });
    }
  });
}
