import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

import { createBackend } from '../src/backend.js';
import { createInboundHandler, deliverPlan } from '../src/handler.js';
import { UNAVAILABLE_TEXT } from '../src/logic.js';
import { createServer } from '../src/server.js';
import { fakeBackend, fakeWa, sampleReply, silentLog } from './fixtures.js';

// ---------- HTTP server (/health, /send) with a fake transport, on 127.0.0.1 only ----------
const state = { connected: true, delivered: [], failNext: false };
const transport = {
  isConnected: () => state.connected,
  detail: () => (state.connected ? 'session logged in' : 'waiting for QR scan'),
  deliver: async (plan) => {
    if (state.failNext) { state.failNext = false; throw new Error('boom'); }
    state.delivered.push(plan);
  },
};
let server;
let base;

before(async () => {
  server = createServer({ transport, log: silentLog });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const post = (body) => fetch(`${base}/send`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: typeof body === 'string' ? body : JSON.stringify(body),
});

test('GET /health connected and degraded', async () => {
  state.connected = true;
  let res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok', connected: true, detail: 'session logged in' });
  state.connected = false;
  res = await fetch(`${base}/health`);
  assert.deepEqual(await res.json(), { status: 'degraded', connected: false, detail: 'waiting for QR scan' });
  state.connected = true;
});

test('POST /send delivers and returns 202', async () => {
  state.delivered = [];
  const r = sampleReply({ attachments: [{ type: 'pdf', url: '/v1/files/aaa', mime: 'application/pdf' }] });
  const res = await post(r);
  assert.equal(res.status, 202);
  assert.deepEqual(await res.json(), { status: 'sent', message_id: r.id });
  assert.equal(state.delivered.length, 1);
  assert.equal(state.delivered[0].to, '25779000102@s.whatsapp.net');
  assert.equal(state.delivered[0].files[0].kind, 'document');
});

test('POST /send 422 on null phone, bad body, bad JSON', async () => {
  let res = await post(sampleReply({ phone: null }));
  assert.equal(res.status, 422);
  assert.match((await res.json()).message, /phone is null/);
  res = await post({ hello: 'world' });
  assert.equal(res.status, 422);
  res = await post('{not json');
  assert.equal(res.status, 422);
});

test('POST /send 503 when not connected or when delivery fails', async () => {
  state.connected = false;
  let res = await post(sampleReply());
  assert.equal(res.status, 503);
  state.connected = true;
  state.failNext = true;
  res = await post(sampleReply());
  assert.equal(res.status, 503);
});

test('unknown route 404', async () => {
  const res = await fetch(`${base}/nope`);
  assert.equal(res.status, 404);
});

// ---------- inbound handler with fake socket and fake backend ----------
const textMsg = (text, key = {}) => ({
  key: { id: 'WAMSG1', remoteJid: '25779000102@s.whatsapp.net', fromMe: false, ...key },
  message: { conversation: text },
});

test('text message -> backend inbound -> reply text sent', async () => {
  const wa = fakeWa();
  const backend = fakeBackend();
  const out = await createInboundHandler({ wa, backend, log: silentLog })(textMsg('Horaires agence Ngozi ?'));
  assert.equal(out.handled, true);
  const [, inbound] = backend.calls.find((c) => c[0] === 'inbound');
  assert.equal(inbound.channel, 'whatsapp');
  assert.equal(inbound.phone, '+25779000102');
  assert.equal(inbound.text, 'Horaires agence Ngozi ?');
  assert.deepEqual(wa.calls[0], ['markRead', 'WAMSG1']);
  assert.deepEqual(wa.calls[1], ['typing', '25779000102@s.whatsapp.net', 'composing']);
  assert.ok(wa.calls.some((c) => c[0] === 'sendText' && c[2] === 'Votre ticket TCK-2026-00042 a été mis à jour.'));
  assert.deepEqual(wa.calls.at(-1), ['typing', '25779000102@s.whatsapp.net', 'paused']);
});

test('image with caption -> uploaded, attached, reply PDF fetched and sent as document', async () => {
  const wa = fakeWa();
  const backend = fakeBackend({
    reply: (m) => sampleReply({
      in_reply_to: m.id, text: 'Voici votre simulation.',
      attachments: [{ type: 'pdf', url: '/v1/files/pdf1', mime: 'application/pdf', name: 'simulation_pret.pdf' }],
    }),
  });
  const msg = {
    key: { id: 'WAIMG1', remoteJid: '1234567890@lid', remoteJidAlt: '25779000102@s.whatsapp.net' },
    message: { imageMessage: { caption: 'Ma CNI', mimetype: 'image/jpeg' } },
  };
  const out = await createInboundHandler({ wa, backend, log: silentLog })(msg);
  assert.equal(out.handled, true);
  assert.deepEqual(backend.calls[0], ['uploadFile', 'image/jpeg', 'wa_WAIMG1.jpg', 15]);
  assert.equal(out.inbound.attachments[0].url, '/v1/files/7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11');
  assert.equal(out.inbound.text, 'Ma CNI');
  assert.ok(backend.calls.some((c) => c[0] === 'fetchFile' && c[1] === '/v1/files/pdf1'));
  // replies go back to the chat the message came from (LID chat here)
  assert.ok(wa.calls.some((c) => c[0] === 'sendFile' && c[1] === '1234567890@lid' && c[2] === 'document' && c[3] === 'simulation_pret.pdf'));
});

test('ignored: own, group, foreign number, sticker', async () => {
  const wa = fakeWa();
  const backend = fakeBackend();
  const h = createInboundHandler({ wa, backend, log: silentLog });
  assert.equal((await h(textMsg('x', { fromMe: true }))).reason, 'from_me');
  assert.equal((await h(textMsg('x', { remoteJid: '1203@g.us' }))).reason, 'group');
  assert.equal((await h(textMsg('x', { remoteJid: '33612345678@s.whatsapp.net' }))).reason, 'not_burundi');
  assert.equal((await h({ key: { id: 'S', remoteJid: '25779000102@s.whatsapp.net' }, message: { stickerMessage: {} } })).reason, 'unsupported_content');
  assert.equal(backend.calls.length, 0);
  assert.equal(wa.calls.length, 0);
});

test('backend down -> trilingual unavailable message', async () => {
  const wa = fakeWa();
  const out = await createInboundHandler({ wa, backend: fakeBackend({ fail: true }), log: silentLog })(textMsg('Bonjour'));
  assert.equal(out.reason, 'backend_error');
  assert.ok(wa.calls.some((c) => c[0] === 'sendText' && c[2] === UNAVAILABLE_TEXT));
});

test('handler never logs message text', async () => {
  const lines = [];
  const log = { info: (o, m) => lines.push(JSON.stringify(o) + m), warn() {}, error: (o, m) => lines.push(JSON.stringify(o) + m) };
  await createInboundHandler({ wa: fakeWa(), backend: fakeBackend(), log })(textMsg('PIN 4821 secret'));
  await createInboundHandler({ wa: fakeWa(), backend: fakeBackend({ fail: true }), log })(textMsg('PIN 4821 secret'));
  assert.ok(lines.length > 0);
  assert.ok(lines.every((l) => !l.includes('4821') && !l.includes('+25779000102')));
});

test('deliverPlan sends text then files', async () => {
  const wa = fakeWa();
  await deliverPlan(wa, fakeBackend(), { to: 'j', text: 't', files: [{ kind: 'image', url: '/v1/files/i', mime: 'image/png', name: 'a.png' }] });
  assert.deepEqual(wa.calls.map((c) => c[0]), ['sendText', 'sendFile']);
});

// ---------- backend client against a local fake backend (no internet) ----------
test('backend client: upload multipart, inbound JSON, file fetch, no absolute URLs', async () => {
  const http = await import('node:http');
  const seen = [];
  const fake = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const body = Buffer.concat(chunks).toString('latin1');
      seen.push([req.method, req.url, req.headers['content-type'], body]);
      if (req.url === '/v1/files' && req.method === 'POST') {
        res.writeHead(201, { 'content-type': 'application/json' });
        return res.end(JSON.stringify({ id: 'f1', url: '/v1/files/f1', type: 'image', mime: 'image/jpeg', size_bytes: 3 }));
      }
      if (req.url === '/v1/channels/whatsapp/inbound') {
        res.writeHead(200, { 'content-type': 'application/json' });
        return res.end(JSON.stringify(sampleReply()));
      }
      if (req.url === '/v1/files/f1') { res.writeHead(200); return res.end('PDF'); }
      res.writeHead(500); return res.end();
    });
  });
  await new Promise((r) => fake.listen(0, '127.0.0.1', r));
  const b = createBackend({ baseUrl: `http://127.0.0.1:${fake.address().port}/` });
  try {
    const ref = await b.uploadFile(Buffer.from('abc'), 'image/jpeg', 'x.jpg');
    assert.equal(ref.url, '/v1/files/f1');
    assert.match(seen[0][2], /^multipart\/form-data/);
    assert.match(seen[0][3], /name="file"; filename="x.jpg"/);
    const reply = await b.inbound({ id: 'x' });
    assert.equal(reply.channel, 'whatsapp');
    assert.equal((await b.fetchFile('/v1/files/f1')).toString(), 'PDF');
    await assert.rejects(() => b.fetchFile('https://example.com/x.pdf'), /absolute URLs/);
    await assert.rejects(() => b.fetchFile('/v1/files/missing'), /500/);
  } finally {
    fake.close();
  }
});
