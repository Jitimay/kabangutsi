// Fictional test data only.

export function sampleReply(overrides = {}) {
  return {
    id: '0a1b2c3d-4e5f-4a6b-9c8d-7e6f5a4b3c2d',
    conversation_id: '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e',
    in_reply_to: null,
    channel: 'whatsapp',
    phone: '+25779000102',
    session_id: '+25779000102',
    lang: 'fr',
    text: 'Votre ticket TCK-2026-00042 a été mis à jour.',
    short_text: 'Ticket TCK-2026-00042 mis a jour.',
    speaker: 'agent',
    intent: null,
    actions: [],
    attachments: [],
    expected_input: 'text',
    handoff: false,
    end_session: false,
    model_used: null,
    model_notice: null,
    ts: '2026-11-02T09:31:05Z',
    ...overrides,
  };
}

/** Records every call made through the `wa` port. */
export function fakeWa({ media = Buffer.from('fake-jpeg-bytes') } = {}) {
  const calls = [];
  return {
    calls,
    markRead: async (key) => { calls.push(['markRead', key.id]); },
    typing: async (jid, kind = 'composing') => { calls.push(['typing', jid, kind]); },
    sendText: async (jid, text) => { calls.push(['sendText', jid, text]); },
    sendFile: async (jid, f, data) => { calls.push(['sendFile', jid, f.kind, f.name, data.length]); },
    downloadMedia: async () => media,
  };
}

/** In-memory backend: records calls, answers like the contract. */
export function fakeBackend({ reply = (m) => sampleReply({ in_reply_to: m.id, phone: m.phone, session_id: m.phone }), fail = false } = {}) {
  const calls = [];
  return {
    calls,
    async uploadFile(buf, mime, name) {
      calls.push(['uploadFile', mime, name, buf.length]);
      return { id: '7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11', url: '/v1/files/7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11', type: 'image', mime, size_bytes: buf.length, created_at: '2026-11-02T09:02:10Z' };
    },
    async inbound(msg) {
      calls.push(['inbound', msg]);
      if (fail) throw new Error('backend down');
      return reply(msg);
    },
    async fetchFile(url) {
      calls.push(['fetchFile', url]);
      return Buffer.from('%PDF-1.7 fake');
    },
  };
}

export const silentLog = { info() {}, warn() {}, error() {}, child() { return silentLog; } };
