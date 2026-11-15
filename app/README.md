# The app everything else is about

A small Flask shop. It never learns about CI: `compose/` grows its **containers**,
`../pipeline/` grows the **workflow** around it.

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
COUNTER_FILE=/tmp/visits.txt python -m pytest tests -q      # 4 passed
```

| Endpoint | Depends on |
|---|---|
| `/health` | nothing — the process answers, or it does not |
| `/ready` | its store: **file** with no `DATABASE_URL`, **postgres** with one |
| `/visits` | state that has to survive one request to the next |
| `/price/<sku>` | the **partner**, which we do not own |

| Test | The claim |
|---|---|
| `test_health_is_ok` | the process answers |
| `test_ready_reports_the_file_store…` | no `DATABASE_URL` means readiness says **file** |
| `test_visits_counts_up` | our own state survives one request to the next |
| `test_price_fails_loudly…` | pointed at a dead port the app answers **502** and names the URL — it does not hang and does not invent a price |
| `test_integration_db.py` | writes rows and reads them back, against the image in `CATSHOP_IMAGE`. This is what `../pipeline/12-cache-testcontainers` measures |

Every workflow from `../pipeline/03-actions` onward reaches this folder through one
composite action, so there is a single copy of "install and test" in the repository:

```yaml
- uses: ./.github/actions/install-and-test
  with:
    python-version: '3.12'
```

It sets up Python with a pip cache keyed on `requirements*.txt`, installs both requirement
files, runs `pytest tests -q`, and reports how many passed as a step output.

`compose/README.md` has the container steps and the three Dockerfiles.
