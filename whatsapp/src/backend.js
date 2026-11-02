// Backend HTTP client (contracts/openapi.yaml): file upload, channel inbound, file download.
// Uses Node's built-in fetch / FormData / Blob. The backend is on the internal Docker network.

export class BackendError extends Error {
  constructor(message, status) {
    super(message);
    this.status = status;
  }
}

export function createBackend({ baseUrl, timeoutMs = 120_000, fetchImpl = globalThis.fetch }) {
  const base = baseUrl.replace(/\/+$/, '');

  async function call(path, init = {}, timeout = timeoutMs) {
    let res;
    try {
      res = await fetchImpl(base + path, { ...init, signal: AbortSignal.timeout(timeout) });
    } catch (err) {
      throw new BackendError(`backend unreachable: ${err.name}`, 0);
    }
    if (!res.ok) throw new BackendError(`backend ${init.method ?? 'GET'} ${path} -> ${res.status}`, res.status);
    return res;
  }

  return {
    /** POST /v1/files -> FileRef {id, url, type, mime, size_bytes, created_at} */
    async uploadFile(buffer, mime, filename) {
      const form = new FormData();
      form.append('file', new Blob([buffer], { type: mime }), filename);
      const res = await call('/v1/files', { method: 'POST', body: form }, 60_000);
      return res.json();
    },

    /** POST /v1/channels/whatsapp/inbound -> OutgoingReply (LLM turn: can take a while on CPU) */
    async inbound(message) {
      const res = await call('/v1/channels/whatsapp/inbound', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(message),
      });
      return res.json();
    },

    /** GET a backend-relative URL (/v1/files/{id}) -> Buffer */
    async fetchFile(url) {
      if (/^https?:\/\//i.test(url)) throw new BackendError('absolute URLs are not allowed', 0);
      const res = await call(url.startsWith('/') ? url : `/${url}`, {}, 60_000);
      return Buffer.from(await res.arrayBuffer());
    },
  };
}
