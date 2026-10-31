import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';

import Ajv2020 from 'ajv/dist/2020.js';
import addFormats from 'ajv-formats';

import {
  buildInbound, extractContent, ignoreReason, maskPhone, MAX_TEXT, normalizePhone, phoneToJid,
  replyToPlan, senderJid, validateReply,
} from '../src/logic.js';
import { sampleReply } from './fixtures.js';

const SCHEMA_PATH = new URL('../../contracts/message.schema.json', import.meta.url);
const haveContracts = existsSync(SCHEMA_PATH);
let validate;
if (haveContracts) {
  const ajv = new Ajv2020({ strict: false, allErrors: true });
  addFormats(ajv);
  const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));
  ajv.addSchema(schema);
  validate = (def, data) => {
    const v = ajv.getSchema(`${schema.$id}#/$defs/${def}`);
    const ok = v(data);
    assert.ok(ok, JSON.stringify(v.errors));
  };
}

test('normalizePhone: same rules as backend/channels/text.py', () => {
  for (const raw of ['+25779000101', '25779000101', '0025779000101', '79000101', '79 00 01 01',
    '25779000101@s.whatsapp.net', '25779000101:12@s.whatsapp.net']) {
    assert.equal(normalizePhone(raw), '+25779000101', raw);
  }
  for (const raw of [null, '', '+33612345678', '12345', '+2577900010', '123456789012345@lid']) {
    assert.equal(normalizePhone(raw), null, String(raw));
  }
});

test('phoneToJid and maskPhone', () => {
  assert.equal(phoneToJid('+25779000101'), '25779000101@s.whatsapp.net');
  assert.equal(maskPhone('+25779000101'), '+2577900**01');
});

test('senderJid prefers the phone JID, also for LID chats', () => {
  assert.equal(senderJid({ remoteJid: '25779000101@s.whatsapp.net' }), '25779000101@s.whatsapp.net');
  assert.equal(senderJid({ remoteJid: '1234567890@lid', remoteJidAlt: '25779000102@s.whatsapp.net' }),
    '25779000102@s.whatsapp.net');
  assert.equal(senderJid({ remoteJid: '1234567890@lid' }), null);
});

test('ignoreReason: own, group, status, newsletter', () => {
  assert.equal(ignoreReason({ fromMe: true, remoteJid: '25779000101@s.whatsapp.net' }), 'from_me');
  assert.equal(ignoreReason({ remoteJid: '120363000000000000@g.us' }), 'group');
  assert.equal(ignoreReason({ remoteJid: 'status@broadcast' }), 'broadcast');
  assert.equal(ignoreReason({ remoteJid: '1203@newsletter' }), 'newsletter');
  assert.equal(ignoreReason({ remoteJid: '25779000101@s.whatsapp.net' }), null);
});

test('extractContent: text, extended text, caption, image, voice note, ephemeral', () => {
  assert.deepEqual(extractContent({ conversation: ' Bonjour ' }), { text: 'Bonjour', media: null });
  assert.deepEqual(extractContent({ extendedTextMessage: { text: 'Hi' } }), { text: 'Hi', media: null });
  assert.deepEqual(extractContent({ imageMessage: { caption: 'Ma CNI', mimetype: 'image/jpeg' } }),
    { text: 'Ma CNI', media: { type: 'image', mime: 'image/jpeg' } });
  assert.deepEqual(extractContent({ audioMessage: { mimetype: 'audio/ogg; codecs=opus', ptt: true } }),
    { text: '', media: { type: 'audio', mime: 'audio/ogg; codecs=opus' } });
  assert.deepEqual(extractContent({ ephemeralMessage: { message: { conversation: 'eph' } } }),
    { text: 'eph', media: null });
  assert.deepEqual(extractContent({ stickerMessage: {} }), { text: '', media: null });
});

test('buildInbound matches contracts/message.schema.json InboundMessage', { skip: !haveContracts }, () => {
  const msg = buildInbound({
    phone: '+25779000102', text: "Voici ma carte d'identité",
    attachments: [{ type: 'image', url: '/v1/files/7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11', mime: 'image/jpeg', size_bytes: 284311 }],
    date: new Date('2026-11-02T09:02:11.123Z'),
  });
  assert.equal(msg.channel, 'whatsapp');
  assert.equal(msg.session_id, '+25779000102');
  assert.equal(msg.lang, null);
  assert.equal(msg.ts, '2026-11-02T09:02:11Z');
  validate('InboundMessage', msg);
  validate('InboundMessage', buildInbound({ phone: '+25779000102', text: 'Bonjour' }));
});

test('buildInbound rejects bad phone and empty message', () => {
  assert.throws(() => buildInbound({ phone: '+33612345678', text: 'x' }));
  assert.throws(() => buildInbound({ phone: '+25779000102', text: '' }));
});

test('validateReply: accepts contract example, flags null phone', { skip: !haveContracts }, () => {
  const r = sampleReply();
  validate('OutgoingReply', r);
  assert.deepEqual(validateReply(r), []);
  assert.match(validateReply({ ...r, phone: null })[0], /phone is null/);
  assert.ok(validateReply({ ...r, short_text: 'x'.repeat(161) }).length > 0);
  assert.ok(validateReply({ text: 'x' }).length > 0);
  assert.ok(validateReply([]).length > 0);
});

test('replyToPlan: text, model_notice in italics, pdf as document', () => {
  const plan = replyToPlan(sampleReply({
    model_notice: 'Modèle changé : gemma4:e4b.',
    attachments: [
      { type: 'pdf', url: '/v1/files/aaa', mime: 'application/pdf', name: 'simulation_pret.pdf' },
      { type: 'image', url: '/v1/files/bbb', mime: 'image/png' },
      { type: 'audio', url: '/v1/files/ccc', mime: 'audio/wav' },
      { type: 'audio', url: '/v1/files/ddd', mime: 'audio/ogg; codecs=opus' },
    ],
  }));
  assert.equal(plan.to, '25779000102@s.whatsapp.net');
  assert.ok(plan.text.endsWith('\n\n_Modèle changé : gemma4:e4b._'));
  assert.deepEqual(plan.files.map((f) => f.kind), ['document', 'image', 'audio', 'audio']);
  assert.equal(plan.files[0].name, 'simulation_pret.pdf');
  assert.equal(plan.files[1].name, 'kabangutsi_2.jpg');
  assert.equal(plan.files[2].ptt, false);
  assert.equal(plan.files[3].ptt, true);
});

test('replyToPlan caps text at 4096', () => {
  const plan = replyToPlan(sampleReply({ text: 'mot '.repeat(3000) }));
  assert.ok(plan.text.length <= MAX_TEXT);
  assert.ok(plan.text.endsWith('...'));
});
