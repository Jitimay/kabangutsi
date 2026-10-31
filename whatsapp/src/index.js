// Entry point: WhatsApp bridge on port 8004 (contracts/adapter_api.yaml).

import pino from 'pino';

import { createBackend } from './backend.js';
import { createInboundHandler, deliverPlan } from './handler.js';
import { createServer } from './server.js';
import { startWhatsApp } from './wa.js';

const PORT = Number(process.env.PORT ?? 8004);
const BACKEND_URL = process.env.BACKEND_URL ?? 'http://backend:8000';
const SESSION_DIR = process.env.SESSION_DIR ?? '/session';
const log = pino({ level: process.env.LOG_LEVEL ?? 'info' });

const backend = createBackend({ baseUrl: BACKEND_URL });
let handle = async () => {};
const bridge = startWhatsApp({ sessionDir: SESSION_DIR, log, onMessage: (m) => handle(m) });
handle = createInboundHandler({ wa: bridge.wa, backend, log });

const server = createServer({
  transport: { ...bridge.transport, deliver: (plan) => deliverPlan(bridge.wa, backend, plan) },
  log,
});
server.listen(PORT, '0.0.0.0', () => log.info({ port: PORT, backend: BACKEND_URL }, 'whatsapp-bridge listening'));

bridge.start().catch((err) => log.error({ err: err.message }, 'WhatsApp start failed'));

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    bridge.stop();
    server.close(() => process.exit(0));
  });
}
