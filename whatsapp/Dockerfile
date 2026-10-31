# Kabangutsi WhatsApp bridge (T4, F16) — Baileys, no browser. Port 8004.
# All npm packages are installed at build time; at runtime the only internet traffic is
# WhatsApp itself (the one allowed exception to the offline rule).
FROM node:20-slim

ENV NODE_ENV=production \
    PORT=8004 \
    SESSION_DIR=/session \
    BACKEND_URL=http://backend:8000

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

COPY src ./src

RUN mkdir -p /session && chown -R node:node /session /app
USER node

VOLUME ["/session"]
EXPOSE 8004

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8004/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/index.js"]
