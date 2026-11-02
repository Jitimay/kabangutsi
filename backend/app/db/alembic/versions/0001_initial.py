"""Initial schema: executes contracts/db_schema.sql (copied as 0001_initial.sql; a test checks it is identical).

Revision ID: 0001_initial
"""

import re
from pathlib import Path

from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None

SQL = Path(__file__).with_name("0001_initial.sql")


def upgrade() -> None:
    conn = op.get_bind()
    # asyncpg prepares one statement at a time; the file has no $$ bodies, so split on ";" at line end.
    for stmt in split_sql(SQL.read_text(encoding="utf-8")):
        conn.exec_driver_sql(stmt)


def split_sql(sql: str) -> list[str]:
    body = "\n".join(line.split("--", 1)[0] if not line.lstrip().startswith("--") else "" for line in sql.splitlines())
    return [s.strip() for s in re.split(r";\s*$", body, flags=re.M) if s.strip()]


def downgrade() -> None:
    op.execute(
        "DROP TABLE IF EXISTS files, model_events, card_block_requests, sessions, tickets, call_turns, calls, "
        "agents, kb_chunks, kb_articles, loan_products, branches, cards, customers CASCADE"
    )
    op.execute("DROP SEQUENCE IF EXISTS card_block_ref_seq, ticket_number_seq")
