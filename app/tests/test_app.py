"""The tests the pipeline runs. No Docker, no database, no network.

Every one of these runs in under a second on a bare runner, which is the whole
reason the test job is the FIRST job: it is the cheapest way to find out the
commit is broken.

COUNTER_FILE is pointed at a temporary directory, because the app's default is
/data/visits.txt and a runner has no /data. That is not a hack — it is the same
"everything comes from the environment" rule the app was written to, used by a
test instead of by Compose.
"""
import importlib
import os

import pytest


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("COUNTER_FILE", str(tmp_path / "visits.txt"))
    monkeypatch.delenv("DATABASE_URL", raising=False)
    # the module reads its configuration at import time, so re-import it
    import app as app_module
    importlib.reload(app_module)
    app_module.app.config.update(TESTING=True)
    return app_module.app.test_client()


def test_health_is_ok(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.data.decode().strip() == "ok"


def test_ready_reports_the_file_store_when_there_is_no_database(client):
    body = client.get("/ready").get_json()
    assert body["ready"] is True
    assert body["store"].startswith("file:")


def test_visits_counts_up(client):
    first = client.get("/visits").get_json()["visits"]
    second = client.get("/visits").get_json()["visits"]
    assert second == first + 1


def test_price_fails_loudly_when_the_partner_is_unreachable(client, monkeypatch):
    """We do not own the partner, so a test must never call it.

    Pointed at a port nothing is listening on, the app must answer 502 and say
    which URL it tried — not hang, and not pretend the price is zero.
    """
    monkeypatch.setenv("PARTNER_URL", "http://127.0.0.1:9")
    monkeypatch.setenv("PARTNER_TIMEOUT", "0.25")
    import app as app_module
    importlib.reload(app_module)
    r = app_module.app.test_client().get("/price/MK-II")
    assert r.status_code == 502
    body = r.get_json()
    assert body["sku"] == "MK-II"
    assert "127.0.0.1:9" in body["source"]
