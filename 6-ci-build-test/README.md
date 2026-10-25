# Step 6 — build the application and test it

**Files:** `.github/workflows/ci.yml`, `tests/test_app.py`, `requirements-dev.txt`, plus the
app and `Dockerfile` carried unchanged from step 1.

The first step where **a machine that is not yours** runs your code. Nothing is published:
no registry, no image pushed, no credentials. That is step 7.

```bash
# what the pipeline does, on your own laptop first
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
COUNTER_FILE=/tmp/visits.txt python -m pytest tests -q      # 4 passed
```

## The six parts of the workflow, in the order they appear

| # | Key | What it decides | Get it wrong and… |
|---|---|---|---|
| 1 | `name:` | what the run is called in the Actions tab | left out, GitHub uses the file path and every run looks the same |
| 2 | `on:` | **the subscription.** Which events deliver a run | `on: push` alone and a pull request from a fork is never checked |
| 3 | `permissions:` | how wide the automatic token is | the default is wider than a test job needs, forever |
| 4 | `runs-on:` | a **label query**, not a machine name | resolved before any machine exists, so it cannot read `runner.*` |
| 5 | `env:` | variables for every step **in this job** | put it at workflow level and a later job inherits something it should not |
| 6 | `steps:` | `uses:` is somebody else's steps, `run:` is a shell command | there is no third kind |

## Why the test job comes first, and alone

The tests run in under a second on a bare runner. That makes them the cheapest possible
way to find out the commit is broken — so they run before anything expensive, and nothing
downstream starts until they pass.

Step 7 adds a second job with `needs: test`, and that one word is what makes *"the build
fails when a test fails"* true rather than aspirational.

## What the tests actually assert, and why

| Test | The claim |
|---|---|
| `test_health_is_ok` | the process answers at all |
| `test_ready_reports_the_file_store…` | with no `DATABASE_URL`, readiness says **file**. Same image, different composition |
| `test_visits_counts_up` | our own state survives one request to the next |
| `test_price_fails_loudly…` | **we do not own the partner, so a test must never call it.** Pointed at a dead port, the app answers 502 and names the URL it tried — it does not hang and does not invent a price |

That last one is the honest version of testing against somebody else's API. Stubbing it
properly — WireMock, Testcontainers — is a later step.

## `COUNTER_FILE` is the lesson, not a workaround

The app defaults to `/data/visits.txt`, and a runner has no `/data`. The fix is not to
change the app: it is to set the environment, in the job's `env:` block, exactly as Compose
sets it locally and as a deployment will set it in production.

**Everything comes from the environment. Nothing comes from the machine it happens to run
on.** The test suite is the third thing to prove it.

## diff against the step before

```bash
diff -ru -x README.md 1-dockerfile 6-ci-build-test
```

Everything that is new is CI. `app.py`, `Dockerfile` and `requirements.txt` are byte for
byte the file from step 1 — **the application did not learn about pipelines.**
