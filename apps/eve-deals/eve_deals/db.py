"""SQLite persistence: OAuth tokens, universe (station/system/region) cache, and found deals."""

import sqlite3
import time
from contextlib import contextmanager

from eve_deals.config import DB_PATH

SCHEMA = """
CREATE TABLE IF NOT EXISTS tokens (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    character_id INTEGER NOT NULL,
    character_name TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS universe_cache (
    kind TEXT NOT NULL,       -- 'station_system', 'system_region', 'name_id'
    key TEXT NOT NULL,        -- e.g. station_id, system_id, or lowercased name
    value TEXT NOT NULL,      -- resolved id/name as text
    PRIMARY KEY (kind, key)
);

CREATE TABLE IF NOT EXISTS deals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    polled_at REAL NOT NULL,
    contract_id INTEGER NOT NULL,
    system_id INTEGER NOT NULL,
    system_name TEXT,
    title TEXT,
    price REAL,
    fair_value REAL,
    discount_pct REAL,
    item_summary TEXT,
    UNIQUE(contract_id, polled_at)
);
"""


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with get_conn() as conn:
        conn.executescript(SCHEMA)


@contextmanager
def db_cursor():
    conn = get_conn()
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


# --- tokens -----------------------------------------------------------------

def save_tokens(character_id, character_name, access_token, refresh_token, expires_in_seconds):
    expires_at = time.time() + expires_in_seconds
    with db_cursor() as conn:
        conn.execute(
            """
            INSERT INTO tokens (id, character_id, character_name, access_token, refresh_token, expires_at)
            VALUES (1, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                character_id=excluded.character_id,
                character_name=excluded.character_name,
                access_token=excluded.access_token,
                refresh_token=excluded.refresh_token,
                expires_at=excluded.expires_at
            """,
            (character_id, character_name, access_token, refresh_token, expires_at),
        )


def get_tokens():
    with db_cursor() as conn:
        row = conn.execute("SELECT * FROM tokens WHERE id = 1").fetchone()
        return dict(row) if row else None


# --- universe cache -----------------------------------------------------------

def cache_get(kind, key):
    with db_cursor() as conn:
        row = conn.execute(
            "SELECT value FROM universe_cache WHERE kind = ? AND key = ?", (kind, str(key))
        ).fetchone()
        return row["value"] if row else None


def cache_set(kind, key, value):
    with db_cursor() as conn:
        conn.execute(
            """
            INSERT INTO universe_cache (kind, key, value) VALUES (?, ?, ?)
            ON CONFLICT(kind, key) DO UPDATE SET value=excluded.value
            """,
            (kind, str(key), str(value)),
        )


# --- deals --------------------------------------------------------------------

def save_deal(polled_at, contract_id, system_id, system_name, title, price, fair_value, discount_pct, item_summary):
    with db_cursor() as conn:
        conn.execute(
            """
            INSERT OR IGNORE INTO deals
            (polled_at, contract_id, system_id, system_name, title, price, fair_value, discount_pct, item_summary)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (polled_at, contract_id, system_id, system_name, title, price, fair_value, discount_pct, item_summary),
        )


def get_deals_for_poll(polled_at):
    with db_cursor() as conn:
        rows = conn.execute(
            "SELECT * FROM deals WHERE polled_at = ? ORDER BY discount_pct DESC", (polled_at,)
        ).fetchall()
        return [dict(r) for r in rows]
