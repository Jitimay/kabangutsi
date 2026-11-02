// Baileys glue: session, QR in the logs, reconnect, and the `wa` port used by handler.js.
// The ONLY part of Kabangutsi that talks to the internet (WhatsApp servers).

import makeWASocket, {
  Browsers, DisconnectReason, downloadMediaMessage, useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import qrcode from 'qrcode-terminal';

export function startWhatsApp({ sessionDir, log, onMessage }) {
  const state = { connected: false, detail: 'starting', sock: null, stopped: false, retries: 0 };

  const wa = {
    markRead: (key) => state.sock.readMessages([key]),
    typing: (jid, kind = 'composing') => state.sock.sendPresenceUpdate(kind, jid),
    sendText: (jid, text) => state.sock.sendMessage(jid, { text }),
    sendFile: (jid, f, data) => {
      if (f.kind === 'document') return state.sock.sendMessage(jid, { document: data, mimetype: f.mime, fileName: f.name });
      if (f.kind === 'image') return state.sock.sendMessage(jid, { image: data, mimetype: f.mime });
      return state.sock.sendMessage(jid, { audio: data, mimetype: f.mime, ptt: Boolean(f.ptt) });
    },
    downloadMedia: (msg) => downloadMediaMessage(msg, 'buffer', {},
      { logger: log, reuploadRequest: state.sock.updateMediaMessage }),
  };

  async function connect() {
    const { state: auth, saveCreds } = await useMultiFileAuthState(sessionDir);
    const sock = makeWASocket({
      auth,
      logger: log.child({ module: 'baileys' }, { level: 'warn' }),
      browser: Browsers.ubuntu('Kabangutsi'),
      markOnlineOnConnect: false,
      syncFullHistory: false,
    });
    state.sock = sock;
    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', ({ connection, lastDisconnect, qr }) => {
      if (qr) {
        state.detail = 'waiting for QR scan (see logs)';
        log.warn('Scan this QR with the DEDICATED TEST number (WhatsApp > Linked devices). Never a personal number.');
        qrcode.generate(qr, { small: true }, (code) => process.stdout.write(`${code}\n`));
      }
      if (connection === 'open') {
        state.connected = true;
        state.retries = 0;
        state.detail = 'session logged in';
        log.info('WhatsApp connected');
      }
      if (connection === 'close') {
        state.connected = false;
        const code = lastDisconnect?.error?.output?.statusCode;
        if (code === DisconnectReason.loggedOut) {
          state.detail = 'logged out: delete the session volume and scan a new QR';
          log.error(state.detail);
          return;
        }
        if (state.stopped) return;
        state.retries += 1;
        const delay = Math.min(30_000, 1000 * 2 ** Math.min(state.retries, 5));
        state.detail = `disconnected (code ${code ?? '?'}), reconnecting in ${delay / 1000}s`;
        log.warn(state.detail);
        setTimeout(() => connect().catch((e) => log.error({ err: e.message }, 'reconnect failed')), delay);
      }
    });

    sock.ev.on('messages.upsert', ({ messages, type }) => {
      if (type !== 'notify') return;
      for (const m of messages) {
        onMessage(m).catch((e) => log.error({ id: m.key?.id, err: e.message }, 'handler crashed'));
      }
    });
  }

  return {
    wa,
    start: connect,
    stop: () => { state.stopped = true; state.sock?.end?.(undefined); },
    transport: {
      isConnected: () => state.connected,
      detail: () => state.detail,
    },
  };
}
