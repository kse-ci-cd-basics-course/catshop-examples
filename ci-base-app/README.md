# The app the CI examples run against

One app, two folders of examples pointed at it. `docker/` grows the *application*;
`pipeline/` grows the *workflow*. The app itself never learns about either.

```
app.py · requirements.txt · requirements-dev.txt · Dockerfile · tests/
```

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt
COUNTER_FILE=/tmp/visits.txt python -m pytest tests -q      # 4 passed
```

## The workflows that use it

The chapters are in `../pipeline/` and the ones that actually run are in
`../.github/workflows/` — **GitHub reads workflows from the repository root and nowhere
else**, which is why a `ci.yml` in a chapter folder is just a text file.

Every chapter from `03-actions` onward reaches this folder through one composite action,
`../.github/actions/install-and-test`, so there is one copy of "install and test" in the
repository:

```yaml
- uses: ./.github/actions/install-and-test
  with:
    python-version: '3.12'
```

It sets up Python with a pip cache keyed on `requirements*.txt`, installs both requirement
files, runs `pytest tests -q`, and reports how many passed as a step output.

## The tests

| Test | The claim |
|---|---|
| `test_health_is_ok` | the process answers |
| `test_ready_reports_the_file_store…` | no `DATABASE_URL` means readiness says **file** |
| `test_visits_counts_up` | our own state survives one request to the next |
| `test_price_fails_loudly…` | **we do not own the partner.** Pointed at a dead port the app answers 502 and names the URL — it does not hang and does not invent a price |

## Two things worth stopping on

**`09-events.yml` is the only one with `paths:`.** Scoping every example would have been
noise; one is the lesson.

**"Merge" is not an event.** Merging a pull request is a push to the base branch, so a
merge arrives as `push` and there is no `on: merge` to subscribe to. `on: push` to `main`
*is* "when something is merged".

### The event does not have to come from GitHub

`repository_dispatch` takes a `client_payload` and arrives with no commit behind it:

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{"event_type":"dataset-published",
       "client_payload":{"dataset":"orders","rows":128400}}'
```

A feature store publishes a new slice and that starts the retraining pipeline. Nobody
committed anything — **the data changed, and the data is the input.**

*On the wording:* "continuous training" is the correct term, not CI. CI integrates **code
changes**; here the artefact that changed is a **dataset**. "The data lake triggers CI"
invites *integrating what?* and the honest answer is nothing.
