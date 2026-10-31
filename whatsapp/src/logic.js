// Pure bridge logic: no Baileys, no network. Mirrors backend/channels/whatsapp.py and
// backend/channels/text.py (phone normalisation, 4096 cap, model_notice in italics,
// attachment kinds). Tested in test/logic.test.js against contracts/message.schema.json.

import { randomUUID } from 'node:crypto';

export const MAX_TEXT = 4096;
export const MAX_ATTACHMENTS = 5;
const PHONE_RE = /^\+257[0-9]{8}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const LANGS = ['fr', 'en', 'rn'];
const CHANNELS = ['phone', 'ussd', 'sms', 'whatsapp', 'web'];
const EXPECTED = ['text', 'pin', 'date_of_birth', 'account_number', 'confirmation', 'menu_choice', 'none'];

/** Any phone/JID form -> '+257XXXXXXXX', or null when not a Burundi number (same rules as text.py). */
export function normalizePhone(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const s = raw.split('@', 1)[0].split(':', 1)[0];
  let digits = s.replace(/\D/g, '');
  if (digits.startsWith('00')) digits = digits.slice(2);
  if (digits.length === 8) digits = '257' + digits;
  if (digits.length === 11 && digits.startsWith('257')) return '+' + digits;
  return null;
}

export function phoneToJid(phone) {
  return phone.replace(/^\+/, '') + '@s.whatsapp.net';
}

/** Mask a phone for logs: +2577900**01. */
export function maskPhone(phone) {
  if (!phone) return '?';
  return phone.length > 6 ? phone.slice(0, -4) + '**' + phone.slice(-2) : '***';
}

export function nowTs(date = new Date()) {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

/**
 * Pick the sender's phone-number JID from a message key. With Baileys v7 the chat JID can be
 * a LID ('...@lid'); the phone JID is then in remoteJidAlt / participantAlt / senderPn.
 */
export function senderJid(key = {}) {
  const candidates = [key.remoteJid, key.remoteJidAlt, key.senderPn, key.participantAlt, key.participant];
  return candidates.find((j) => typeof j === 'string' && j.endsWith('@s.whatsapp.net')) ?? null;
}

/** Why a message must be ignored, or null if it should be handled. */
export function ignoreReason(key = {}) {
  const jid = key.remoteJid ?? '';
  if (key.fromMe) return 'from_me';
  if (jid.endsWith('@g.us')) return 'group';
  if (jid === 'status@broadcast' || jid.endsWith('@broadcast')) return 'broadcast';
  if (jid.endsWith('@newsletter')) return 'newsletter';
  return null;
}

/** Unwrap ephemeral / view-once containers. */
function unwrap(message) {
  let m = message ?? {};
  for (let i = 0; i < 4; i++) {
    const inner = m.ephemeralMessage?.message ?? m.viewOnceMessage?.message
      ?? m.viewOnceMessageV2?.message ?? m.documentWithCaptionMessage?.message;
    if (!inner) break;
    m = inner;
  }
  return m;
}

/**
 * What a WhatsApp message contains: { text, media } where media is
 * { type: 'image'|'audio', mime } or null. Unsupported content -> text '' and media null.
 */
export function extractContent(message) {
  const m = unwrap(message);
  const text = m.conversation ?? m.extendedTextMessage?.text ?? m.imageMessage?.caption ?? '';
  let media = null;
  if (m.imageMessage) media = { type: 'image', mime: m.imageMessage.mimetype || 'image/jpeg' };
  else if (m.audioMessage) media = { type: 'audio', mime: m.audioMessage.mimetype || 'audio/ogg' };
  return { text: String(text).trim().slice(0, 4000), media };
}

/** Standard InboundMessage (contracts/message.schema.json). */
export function buildInbound({ phone, text = '', attachments = [], date = new Date(), id = randomUUID() }) {
  if (!PHONE_RE.test(phone ?? '')) throw new Error('phone must be +257XXXXXXXX');
  const atts = attachments.slice(0, MAX_ATTACHMENTS).map(cleanAttachment);
  if (!text && atts.length === 0) throw new Error('empty message');
  return {
    id, channel: 'whatsapp', phone, session_id: phone, lang: null,
    text: text.slice(0, 4000), attachments: atts, ts: nowTs(date),
  };
}

/** Attachment from a backend FileRef (POST /v1/files response). */
export function attachmentFromFileRef(ref, fallback = {}) {
  return cleanAttachment({
    type: ref.type ?? fallback.type, url: ref.url, mime: ref.mime ?? fallback.mime,
    size_bytes: ref.size_bytes ?? fallback.size_bytes,
  });
}

function cleanAttachment(a) {
  const out = { type: a.type, url: a.url, mime: a.mime };
  for (const k of ['name', 'size_bytes', 'duration_ms']) if (a[k] !== undefined && a[k] !== null) out[k] = a[k];
  return out;
}

function truncate(text, limit) {
  const t = text.trim();
  if (t.length <= limit) return t;
  let cut = t.slice(0, limit - 3);
  const sp = cut.lastIndexOf(' ');
  if (sp >= cut.length - 20 && sp > 0) cut = cut.slice(0, sp);
  return cut.replace(/[ ,;:.]+$/, '') + '...';
}

/**
 * Minimal structural check of an OutgoingReply body for POST /send.
 * Returns a list of problems (empty = OK). Full JSON Schema validation is done in tests.
 */
export function validateReply(r) {
  const errs = [];
  if (!r || typeof r !== 'object' || Array.isArray(r)) return ['body must be an OutgoingReply object'];
  const req = ['id', 'conversation_id', 'in_reply_to', 'channel', 'phone', 'session_id', 'lang', 'text',
    'short_text', 'speaker', 'intent', 'actions', 'attachments', 'expected_input', 'handoff',
    'end_session', 'model_used', 'model_notice', 'ts'];
  for (const k of req) if (!(k in r)) errs.push(`missing ${k}`);
  if (errs.length) return errs;
  if (typeof r.id !== 'string' || !UUID_RE.test(r.id)) errs.push('id must be a UUID v4');
  if (r.phone === null) errs.push('phone is null: cannot deliver on WhatsApp');
  else if (!PHONE_RE.test(r.phone)) errs.push('phone must be +257XXXXXXXX');
  if (!CHANNELS.includes(r.channel)) errs.push('invalid channel');
  if (!LANGS.includes(r.lang)) errs.push('invalid lang');
  if (typeof r.text !== 'string') errs.push('text must be a string');
  if (typeof r.short_text !== 'string' || r.short_text.length > 160) errs.push('short_text must be <= 160 chars');
  if (!['ai', 'agent', 'system'].includes(r.speaker)) errs.push('invalid speaker');
  if (!EXPECTED.includes(r.expected_input)) errs.push('invalid expected_input');
  if (!Array.isArray(r.attachments)) errs.push('attachments must be an array');
  else r.attachments.forEach((a, i) => {
    if (!a || !['image', 'audio', 'pdf'].includes(a.type) || typeof a.url !== 'string' || typeof a.mime !== 'string') {
      errs.push(`attachments[${i}] needs type (image|audio|pdf), url, mime`);
    }
  });
  if (!Array.isArray(r.actions)) errs.push('actions must be an array');
  if (r.model_notice !== null && typeof r.model_notice !== 'string') errs.push('model_notice must be string or null');
  return errs;
}

/**
 * OutgoingReply -> send plan: { to, text, files: [{ kind, url, mime, name }] }
 * kind: document (pdf) | image | audio. Audio is sent as a voice note (ptt) only when it is
 * ogg/opus, the format WhatsApp plays as a voice note; other audio is sent as a normal audio file.
 */
export function replyToPlan(r) {
  let text = r.text ?? '';
  if (r.model_notice) text = `${text}\n\n_${r.model_notice}_`;
  const files = (r.attachments ?? []).map((a, i) => {
    const kind = { pdf: 'document', image: 'image', audio: 'audio' }[a.type];
    const ext = { pdf: 'pdf', image: 'jpg', audio: 'wav' }[a.type];
    const file = { kind, url: a.url, mime: a.mime, name: a.name || `kabangutsi_${i + 1}.${ext}` };
    if (kind === 'audio') file.ptt = /ogg|opus/.test(a.mime);
    return file;
  });
  return { to: phoneToJid(r.phone), text: truncate(text, MAX_TEXT), files };
}

/** Sent when the backend cannot answer. Kirundi: draft, to be reviewed by a native speaker. */
export const UNAVAILABLE_TEXT = [
  'Service momentanément indisponible, veuillez réessayer plus tard.',
  'Service temporarily unavailable, please try again later.',
  'Serivisi ntiboneka ubu, mugerageze haheze akanya.',
].join('\n');
