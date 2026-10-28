"""
Spaceship shop.

/health  - liveness
/visits  - state (file or postgres)
/price   - partner API dependency
"""
import os
import time
from pathlib import Path

import requests
from flask import Flask, jsonify

app = Flask(__name__)

PARTNER_URL = os.environ.get("PARTNER_URL", "http://partner:8080")
PARTNER_TIMEOUT = float(os.environ.get("PARTNER_TIMEOUT", "2"))
COUNTER_FILE = Path(os.environ.get("COUNTER_FILE", "/data/visits.txt"))
DATABASE_URL = os.environ.get("DATABASE_URL")
DB_RETRIES = int(os.environ.get("DB_RETRIES", "30"))


# --------------------------------------------------------------------- storage
def _db():
    import psycopg

    return psycopg.connect(DATABASE_URL, connect_timeout=3)


def init_db():
    """Retry-based DB initialization."""
    for attempt in range(1, DB_RETRIES + 1):
        try:
            with _db() as conn:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS visits ("
                    "  id serial PRIMARY KEY, at timestamptz DEFAULT now())"
                )
            print(f"db ready ({attempt})", flush=True)
            return True
        except Exception as exc:
            print(f"db not ready ({attempt}/{DB_RETRIES}): {exc}", flush=True)
            time.sleep(1)
    print("giving up on db", flush=True)
    return False


def bump_file():
    COUNTER_FILE.parent.mkdir(parents=True, exist_ok=True)
    n = int(COUNTER_FILE.read_text().strip() or 0) if COUNTER_FILE.exists() else 0
    n += 1
    COUNTER_FILE.write_text(str(n))
    return n


def bump_db():
    with _db() as conn:
        conn.execute("INSERT INTO visits DEFAULT VALUES")
        return conn.execute("SELECT count(*) FROM visits").fetchone()[0]


# --------------------------------------------------------------------- routes
@app.get("/health")
def health():
    return "ok\n"


@app.get("/ready")
def ready():
    try:
        if DATABASE_URL:
            with _db() as conn:
                conn.execute("SELECT 1")
            return jsonify(ready=True, store="postgres")
        COUNTER_FILE.parent.mkdir(parents=True, exist_ok=True)
        return jsonify(ready=True, store=f"file:{COUNTER_FILE}")
    except Exception as exc:
        return jsonify(ready=False, error=str(exc)), 503


@app.get("/visits")
def visits():
    try:
        n = bump_db() if DATABASE_URL else bump_file()
        return jsonify(visits=n, store="postgres" if DATABASE_URL else "file")
    except Exception as exc:
        return jsonify(error=str(exc), store="postgres" if DATABASE_URL else "file"), 503


@app.get("/price/<sku>")
def price(sku):
    url = f"{PARTNER_URL}/v1/catalog/{sku}"
    try:
        r = requests.get(url, timeout=PARTNER_TIMEOUT)
        r.raise_for_status()
        body = r.json()
        return jsonify(sku=sku, price=body.get("price"), currency=body.get("currency"), source=url)
    except Exception as exc:
        return jsonify(sku=sku, error=type(exc).__name__, detail=str(exc)[:200], source=url), 502


if __name__ == "__main__":
    if DATABASE_URL:
        init_db()
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)
