#!/usr/bin/env bash
# Restore the synthetic demo data (run before going on stage).
#   1. Make sure the schema exists: alembic in the backend container if T1's migrations are there,
#      otherwise contracts/db_schema.sql.
#   2. Load scripts/reset_demo.sql (TRUNCATE + INSERT, one transaction).
#   3. Restart the backend so it re-computes the knowledge-base embeddings.
set -euo pipefail
cd "$(dirname "$0")/.."

PGUSER=${POSTGRES_USER:-kabangutsi}
PGDB=${POSTGRES_DB:-kabangutsi}
psql_in() { docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -q -U "$PGUSER" -d "$PGDB" "$@"; }

docker compose up -d postgres >/dev/null
for _ in $(seq 1 30); do
  docker compose exec -T postgres pg_isready -U "$PGUSER" -d "$PGDB" >/dev/null 2>&1 && break
  sleep 1
done

has_tables=$(psql_in -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='customers'")
if [[ "$has_tables" != "1" ]]; then
  if docker compose exec -T backend test -f alembic.ini 2>/dev/null; then
    echo "==> Schema: alembic upgrade head (backend)"
    docker compose exec -T backend alembic upgrade head
  else
    echo "==> Schema: contracts/db_schema.sql"
    psql_in -f /demo/db_schema.sql
  fi
fi

echo "==> Loading demo data"
psql_in -f /demo/reset_demo.sql
psql_in -tAc "SELECT 'customers=' || (SELECT count(*) FROM customers) || ' cards=' || (SELECT count(*) FROM cards)
  || ' branches=' || (SELECT count(*) FROM branches) || ' loan_products=' || (SELECT count(*) FROM loan_products)
  || ' kb_chunks=' || (SELECT count(*) FROM kb_chunks) || ' calls=' || (SELECT count(*) FROM calls)
  || ' tickets=' || (SELECT count(*) FROM tickets)"

if [[ -n "$(docker compose ps -q backend 2>/dev/null)" ]]; then
  echo "==> Restarting backend (re-embeds the knowledge base)"
  docker compose restart backend >/dev/null
fi
echo "Demo data restored."
