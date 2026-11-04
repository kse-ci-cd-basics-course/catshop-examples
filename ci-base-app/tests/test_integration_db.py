"""The integration test the cache chapter measures.

It is deliberately the expensive shape: a real Postgres in a container, a real
schema, real rows written and read back. Nothing here is mocked, because the
point of the chapter is what it costs to start.

Two things make it measurable:

* It READS the image under test from CATSHOP_IMAGE instead of building one. A
  test that builds its own image rebuilds it on every run, and then a cold run
  and a warm run take exactly the same time - which is how people conclude that
  caching does nothing.
* Testcontainers' `reuse` feature is NOT used. Reuse keeps a container alive
  between runs on a developer's laptop; on a runner that is deleted when the job
  ends there is nothing to reuse, so switching it on only hides the real number.

    pytest ci-base-app/tests/test_integration_db.py -q
"""
import os

import psycopg
import pytest
from testcontainers.postgres import PostgresContainer

SCHEMA = """
CREATE TABLE IF NOT EXISTS cats (
    id    SERIAL PRIMARY KEY,
    name  TEXT NOT NULL,
    price NUMERIC(8, 2) NOT NULL
)
"""


@pytest.fixture(scope="module")
def db_url():
    # postgres:16 is pulled on a cold run and already present on a warm one.
    # That pull is one of the two numbers the chapter is about.
    with PostgresContainer("postgres:16") as pg:
        yield pg.get_connection_url().replace("postgresql+psycopg2", "postgresql")


@pytest.fixture(scope="module")
def conn(db_url):
    with psycopg.connect(db_url, autocommit=True) as c:
        c.execute(SCHEMA)
        yield c


def test_the_image_under_test_was_handed_to_us(conn):
    """The pipeline built it; this job loaded it. We do not build images here."""
    assert os.environ.get("CATSHOP_IMAGE"), (
        "CATSHOP_IMAGE is unset - the test would have to build its own image, "
        "and the cold/warm comparison would be meaningless"
    )


def test_a_row_written_is_a_row_read_back(conn):
    conn.execute("DELETE FROM cats")
    conn.execute("INSERT INTO cats (name, price) VALUES (%s, %s)", ("Marsik", 12.50))
    conn.execute("INSERT INTO cats (name, price) VALUES (%s, %s)", ("Barsik", 9.00))

    rows = conn.execute("SELECT name, price FROM cats ORDER BY name").fetchall()
    assert [r[0] for r in rows] == ["Barsik", "Marsik"]
    assert float(rows[1][1]) == 12.50


def test_the_constraint_is_real(conn):
    """A schema that does not enforce anything is a schema that proves nothing."""
    conn.execute("DELETE FROM cats")
    with pytest.raises(psycopg.errors.NotNullViolation):
        conn.execute("INSERT INTO cats (name, price) VALUES (NULL, 1.00)")
