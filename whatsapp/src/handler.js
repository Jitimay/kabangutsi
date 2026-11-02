// Inbound flow: WhatsApp message -> backend -> reply sent back on WhatsApp.
// `wa` is a thin port over the Baileys socket ({ markRead, typing, sendText, sendFile,
// downloadMedia }) so the flow is tested without Baileys or network. Never logs message text.

import {
  attachmentFromFileRef, buildInbound, extractContent, ignoreReason, maskPhone,
  normalizePhone, replyToPlan, senderJid, UNAVAILABLE_TEXT,
} from './logic.js';

const MAX_MEDIA_BYTES = 10 * 1024 * 1024;
const EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'audio/ogg': 'ogg', 'audio/mpeg': 'mp3', 'audio/mp4': 'm4a' };

/** Send a plan's text and files (files fetched from the backend). */
export async function deliverPlan(wa, backend, plan) {
  if (plan.text) await wa.sendText(plan.to, plan.text);
  for (const f of plan.files) {
    const data = await backend.fetchFile(f.url);
    await wa.sendFile(plan.to, f, data);
  }
}

export function createInboundHandler({ wa, backend, log }) {
  return async function handle(msg) {
    const key = msg.key ?? {};
    const reason = ignoreReason(key);
    if (reason) return { handled: false, reason };

    const jid = senderJid(key);
    const phone = normalizePhone(jid);
    if (!phone) {
      log.info({ id: key.id }, 'ignored: sender is not a +257 number');
      return { handled: false, reason: 'not_burundi' };
    }

    const { text, media } = extractContent(msg.message);
    if (!text && !media) return { handled: false, reason: 'unsupported_content' };

    const replyJid = key.remoteJid;  // reply in the same chat (PN or LID)
    await wa.markRead(key).catch(() => {});
    await wa.typing(replyJid).catch(() => {});

    try {
      const attachments = [];
      if (media) {
        const buf = await wa.downloadMedia(msg);
        if (buf.length > MAX_MEDIA_BYTES) {
          log.info({ id: key.id, bytes: buf.length }, 'media too large, skipped');
        } else {
          const name = `wa_${key.id ?? 'media'}.${EXT[media.mime.split(';')[0]] ?? 'bin'}`;
          const ref = await backend.uploadFile(buf, media.mime.split(';')[0], name);
          attachments.push(attachmentFromFileRef(ref, { type: media.type, mime: media.mime.split(';')[0], size_bytes: buf.length }));
        }
      }
      if (!text && attachments.length === 0) return { handled: false, reason: 'empty_after_media' };

      const inbound = buildInbound({ phone, text, attachments });
      log.info({ id: inbound.id, phone: maskPhone(phone), attachments: attachments.length }, 'inbound -> backend');
      const reply = await backend.inbound(inbound);
      // Deliver to the chat the message came from (keeps LID chats working).
      const plan = { ...replyToPlan(reply), to: replyJid };
      await deliverPlan(wa, backend, plan);
      log.info({ id: inbound.id, reply: reply.id, files: plan.files.length }, 'reply sent');
      return { handled: true, inbound, reply };
    } catch (err) {
      log.error({ id: key.id, phone: maskPhone(phone), err: err.message }, 'turn failed');
      await wa.sendText(replyJid, UNAVAILABLE_TEXT).catch(() => {});
      return { handled: false, reason: 'backend_error' };
    } finally {
      await wa.typing(replyJid, 'paused').catch(() => {});
    }
  };
}
