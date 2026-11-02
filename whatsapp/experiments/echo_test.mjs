// Pre-G0 WhatsApp experiment (T4): link a DEDICATED TEST number, receive one text and one image,
// send one text and one image back. No backend involved.
//
//   cd whatsapp && npm ci && node experiments/echo_test.mjs [--allow +257XXXXXXXX]
//
// 1. Scan the QR with the TEST phone (WhatsApp > Linked devices). Never a personal number.
// 2. From another phone, send a text, then an image, to the test number.
// 3. The script replies to each and prints a timing line; it exits after 1 text + 1 image.
// Session is kept in experiments/.auth (git-ignored). Message text is not printed (may contain a PIN).
import makeWASocket, { Browsers, DisconnectReason, downloadMediaMessage, useMultiFileAuthState } from '@whiskeysockets/baileys';
import qrcode from 'qrcode-terminal';
import pino from 'pino';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const allowIdx = process.argv.indexOf('--allow');
const allow = allowIdx > 0 ? process.argv[allowIdx + 1].replace('+', '') : null;
const log = pino({ level: 'warn' });
const seen = { text: false, image: false };
const mask = (jid) => jid.split('@')[0].replace(/^(\d{7})\d+(\d{2})$/, '+$1**$2');

// 1x1 PNG generated in memory: no file, no download.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');

async function connect() {
  const { state, saveCreds } = await useMultiFileAuthState(path.join(here, '.auth'));
  const sock = makeWASocket({ auth: state, logger: log, browser: Browsers.ubuntu('Kabangutsi-test'),
    markOnlineOnConnect: false, syncFullHistory: false });
  sock.ev.on('creds.update', saveCreds);
  sock.ev.on('connection.update', ({ connection, lastDisconnect, qr }) => {
    if (qr) { console.log('Scan with the DEDICATED TEST number:'); qrcode.generate(qr, { small: true }); }
    if (connection === 'open') console.log('connected; send a text then an image to the test number');
    if (connection === 'close') {
      const code = lastDisconnect?.error?.output?.statusCode;
      if (code === DisconnectReason.loggedOut) { console.error('logged out: delete experiments/.auth'); process.exit(1); }
      console.log(`closed (code ${code}), reconnecting`); connect();
    }
  });
  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;
    for (const m of messages) {
      const jid = m.key.remoteJid ?? '';
      if (m.key.fromMe || !jid.endsWith('@s.whatsapp.net')) continue;
      if (allow && !jid.startsWith(allow)) continue;
      const t0 = Date.now();
      if (m.message?.imageMessage) {
        const buf = await downloadMediaMessage(m, 'buffer', {}, { logger: log, reuploadRequest: sock.updateMediaMessage });
        await sock.sendMessage(jid, { image: PNG, mimetype: 'image/png', caption: `Kabangutsi test: image received (${buf.length} bytes)` });
        console.log(`IMAGE in from ${mask(jid)}: ${buf.length} bytes, ${m.message.imageMessage.mimetype}; image out in ${Date.now() - t0} ms`);
        seen.image = true;
      } else if (m.message?.conversation || m.message?.extendedTextMessage) {
        await sock.sendMessage(jid, { text: 'Kabangutsi test: message reçu / message received / ubutumwa bwashitse.' });
        console.log(`TEXT in from ${mask(jid)}; text out in ${Date.now() - t0} ms`);
        seen.text = true;
      }
      if (seen.text && seen.image) { console.log('PASS: 1 text + 1 image in, 1 text + 1 image out'); setTimeout(() => process.exit(0), 2000); }
    }
  });
}
connect();
