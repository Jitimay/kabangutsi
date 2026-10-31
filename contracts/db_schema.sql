-- Kabangutsi database schema v1 (frozen at G0). See db_schema.md for the rules.
-- T1's first Alembic migration must produce exactly this schema (it may simply execute this file).
-- PostgreSQL 16 + pgvector. Idempotent: safe to run on an empty database.

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ---------- reference data (seeded) ----------

CREATE TABLE IF NOT EXISTS customers (
    id              uuid PRIMARY KEY,
    full_name       text        NOT NULL,
    phone           text        NOT NULL UNIQUE CHECK (phone ~ '^\+257[0-9]{8}$'),
    account_number  text        NOT NULL UNIQUE CHECK (account_number ~ '^[0-9]{11}$'),
    province        text        NOT NULL,
    town            text        NOT NULL,
    language        text        NOT NULL CHECK (language IN ('fr','en','rn')),
    date_of_birth   date        NOT NULL,
    pin_hash        text        NOT NULL,              -- argon2id hash, never a plain PIN
    failed_attempts integer     NOT NULL DEFAULT 0,
    locked_until    timestamptz,
    fictional       boolean     NOT NULL DEFAULT true CHECK (fictional),
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cards (
    id              uuid PRIMARY KEY,
    customer_id     uuid        NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    last4           text        NOT NULL CHECK (last4 ~ '^[0-9]{4}$'),
    card_type       text        NOT NULL CHECK (card_type IN ('visa_debit','local_debit','prepaid')),
    status          text        NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked','expired')),
    expires         date        NOT NULL,
    blocked_at      timestamptz,
    block_reason    text        CHECK (block_reason IN ('lost','stolen','blocked','damaged','swallowed_by_atm','fraud_suspected')),
    block_reference text        UNIQUE CHECK (block_reference ~ '^BLK-[0-9]{4}-[0-9]{5}$'),
    UNIQUE (customer_id, last4)
);

CREATE TABLE IF NOT EXISTS branches (
    id              text        PRIMARY KEY,           -- e.g. br-ngozi
    name            text        NOT NULL,
    province        text        NOT NULL,
    town            text        NOT NULL,
    address         text        NOT NULL,
    phone           text        NOT NULL CHECK (phone ~ '^\+257[0-9]{8}$'),
    hours           jsonb       NOT NULL,              -- {"mon":{"open":"08:00","close":"17:00"},...,"sun":null}
    services        text[]      NOT NULL DEFAULT '{}',
    latitude        double precision,
    longitude       double precision,
    fictional       boolean     NOT NULL DEFAULT true CHECK (fictional)
);
CREATE INDEX IF NOT EXISTS branches_province_trgm ON branches USING gin (lower(province) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS branches_town_trgm     ON branches USING gin (lower(town) gin_trgm_ops);

CREATE TABLE IF NOT EXISTS loan_products (
    id               text       PRIMARY KEY,           -- e.g. business_loan
    name             jsonb      NOT NULL,              -- {"fr":..,"en":..,"rn":..}
    description      jsonb      NOT NULL,
    annual_rate_pct  numeric(5,2) NOT NULL CHECK (annual_rate_pct >= 0),
    min_amount       bigint     NOT NULL CHECK (min_amount > 0),
    max_amount       bigint     NOT NULL CHECK (max_amount >= min_amount),
    min_term_months  integer    NOT NULL CHECK (min_term_months > 0),
    max_term_months  integer    NOT NULL CHECK (max_term_months >= min_term_months),
    requirements     jsonb      NOT NULL,              -- {"fr":[..],"en":[..],"rn":[..]}
    fictional        boolean    NOT NULL DEFAULT true CHECK (fictional)
);

CREATE TABLE IF NOT EXISTS kb_articles (
    id          text        PRIMARY KEY,               -- e.g. kb-loan-business-fr
    topic       text        NOT NULL,                  -- e.g. loan_business (same across languages)
    intent      text        NOT NULL CHECK (intent IN ('product_info','account_opening','card_block','loan_info','complaint','branch_info','handoff','other')),
    lang        text        NOT NULL CHECK (lang IN ('fr','en','rn')),
    title       text        NOT NULL,
    body        text        NOT NULL,
    fictional   boolean     NOT NULL DEFAULT true CHECK (fictional),
    UNIQUE (topic, lang)
);

CREATE TABLE IF NOT EXISTS kb_chunks (
    id          text        PRIMARY KEY,               -- <article id>-<n>, e.g. kb-loan-business-fr-0
    article_id  text        NOT NULL REFERENCES kb_articles(id) ON DELETE CASCADE,
    source      text        NOT NULL,                  -- human-readable source (article title)
    lang        text        NOT NULL CHECK (lang IN ('fr','en','rn')),
    chunk_index integer     NOT NULL DEFAULT 0,
    text        text        NOT NULL,
    embedding   vector(768),                           -- nomic-embed-text; filled by the backend, NULL in seed
    tsv         tsvector    GENERATED ALWAYS AS (to_tsvector('simple', text)) STORED
);
CREATE INDEX IF NOT EXISTS kb_chunks_tsv   ON kb_chunks USING gin (tsv);
CREATE INDEX IF NOT EXISTS kb_chunks_trgm  ON kb_chunks USING gin (text gin_trgm_ops);
CREATE INDEX IF NOT EXISTS kb_chunks_lang  ON kb_chunks (lang);
CREATE INDEX IF NOT EXISTS kb_chunks_embed ON kb_chunks USING hnsw (embedding vector_cosine_ops);

CREATE TABLE IF NOT EXISTS agents (
    id          text        PRIMARY KEY,               -- e.g. agent-01
    name        text        NOT NULL,
    languages   text[]      NOT NULL,
    role        text        NOT NULL CHECK (role IN ('agent','supervisor')),
    fictional   boolean     NOT NULL DEFAULT true CHECK (fictional)
);

-- ---------- operational data ----------

CREATE TABLE IF NOT EXISTS calls (
    id              uuid        PRIMARY KEY,           -- = conversation id
    phone           text        CHECK (phone ~ '^\+257[0-9]{8}$'),
    customer_id     uuid        REFERENCES customers(id),  -- set after a successful identity check
    channel         text        NOT NULL CHECK (channel IN ('phone','ussd','sms','whatsapp','web')),
    session_key     text,                              -- adapter session_id (USSD session, phone for SMS/WhatsApp)
    language        text        NOT NULL DEFAULT 'fr' CHECK (language IN ('fr','en','rn')),
    status          text        NOT NULL DEFAULT 'active' CHECK (status IN ('active','queued','with_agent','ended')),
    resolved_by     text        CHECK (resolved_by IN ('ai','agent','abandoned')),
    model           text,                              -- the user's chosen model for the session
    last_intent     text,
    urgency         text        NOT NULL DEFAULT 'low' CHECK (urgency IN ('low','medium','high','critical')),
    frustration     real        NOT NULL DEFAULT 0 CHECK (frustration BETWEEN 0 AND 1),
    handoff_reason  text        CHECK (handoff_reason IN ('customer_request','frustration','low_confidence','no_answer','identity_failed','agent_review','other')),
    summary         text,
    claimed_by      text        REFERENCES agents(id),
    agent_note      text,
    started_at      timestamptz NOT NULL DEFAULT now(),
    queued_at       timestamptz,
    claimed_at      timestamptz,
    ended_at        timestamptz
);
CREATE INDEX IF NOT EXISTS calls_queue   ON calls (status, urgency, queued_at);
CREATE INDEX IF NOT EXISTS calls_session ON calls (channel, session_key) WHERE status <> 'ended';
CREATE INDEX IF NOT EXISTS calls_started ON calls (started_at);

CREATE TABLE IF NOT EXISTS call_turns (
    id          uuid        PRIMARY KEY,
    call_id     uuid        NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    message_id  uuid        UNIQUE,                    -- InboundMessage.id / OutgoingReply.id (idempotency)
    speaker     text        NOT NULL CHECK (speaker IN ('customer','ai','agent','system')),
    agent_id    text        REFERENCES agents(id),
    text        text        NOT NULL,                  -- PIN / date-of-birth answers stored as '••••'
    lang        text        NOT NULL CHECK (lang IN ('fr','en','rn')),
    intent      text,
    confidence  real        CHECK (confidence BETWEEN 0 AND 1),
    frustration real        CHECK (frustration BETWEEN 0 AND 1),
    attachments jsonb       NOT NULL DEFAULT '[]',
    model_used  text,
    reply_json  jsonb,                                 -- full OutgoingReply for ai/agent turns (idempotent replay)
    ts          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS call_turns_call ON call_turns (call_id, ts);

CREATE TABLE IF NOT EXISTS tickets (
    id          uuid        PRIMARY KEY,
    number      text        NOT NULL UNIQUE CHECK (number ~ '^TCK-[0-9]{4}-[0-9]{5}$'),
    call_id     uuid        REFERENCES calls(id),
    customer_id uuid        REFERENCES customers(id),
    phone       text        CHECK (phone ~ '^\+257[0-9]{8}$'),
    category    text        NOT NULL CHECK (category IN ('fees','card','loan','account','service_quality','mobile_banking','atm','other')),
    urgency     text        NOT NULL CHECK (urgency IN ('low','medium','high','critical')),
    summary     text        NOT NULL,
    description text,                                  -- customer's own words
    status      text        NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed')),
    lang        text        NOT NULL CHECK (lang IN ('fr','en','rn')),
    assigned_to text        REFERENCES agents(id),
    attachments jsonb       NOT NULL DEFAULT '[]',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS tickets_status ON tickets (status, urgency, created_at DESC);

CREATE TABLE IF NOT EXISTS sessions (
    session_key  text        PRIMARY KEY,              -- phone, USSD session id or conversation id
    call_id      uuid        REFERENCES calls(id) ON DELETE SET NULL,
    phone        text,
    state        text        NOT NULL DEFAULT 'idle',  -- orchestrator state, e.g. idle, awaiting_account, awaiting_pin, awaiting_confirmation, queued
    context_json jsonb       NOT NULL DEFAULT '{}',    -- never contains a PIN or date of birth
    updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS card_block_requests (
    id           uuid        PRIMARY KEY,              -- confirmation_id
    card_id      uuid        NOT NULL REFERENCES cards(id),
    call_id      uuid        REFERENCES calls(id),
    reason       text        NOT NULL,
    expires_at   timestamptz NOT NULL,
    confirmed_at timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS model_events (
    id                uuid        PRIMARY KEY,
    call_id           uuid        REFERENCES calls(id) ON DELETE CASCADE,
    requested_model   text        NOT NULL,
    used_model        text,                            -- NULL when a non-LLM fallback was used
    capability_needed text        NOT NULL CHECK (capability_needed IN ('completion','vision','audio','tools','embedding')),
    reason            text        NOT NULL CHECK (reason IN ('capability_missing','model_unavailable','no_capable_model')),
    fallback_path     text        CHECK (fallback_path IN ('ocr','stt')),
    notice            text        NOT NULL,
    lang              text        NOT NULL CHECK (lang IN ('fr','en','rn')),
    ts                timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS files (
    id          uuid        PRIMARY KEY,
    kind        text        NOT NULL CHECK (kind IN ('image','audio','pdf')),
    mime        text        NOT NULL,
    size_bytes  bigint      NOT NULL,
    path        text        NOT NULL,                  -- path inside the backend files volume
    call_id     uuid        REFERENCES calls(id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Reference numbers: BLK-YYYY-NNNNN and TCK-YYYY-NNNNN
CREATE SEQUENCE IF NOT EXISTS card_block_ref_seq START 1;
CREATE SEQUENCE IF NOT EXISTS ticket_number_seq  START 1;
