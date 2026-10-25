# Step 9 — what can start a run

**The workflow is `../.github/workflows/example-09.yml`.** GitHub only reads workflows from
the **repository root**, so that is where every runnable example in this repo lives; each
one is scoped to its own folder with `paths:`.

```bash
diff -u ../.github/workflows/example-08.yml ../.github/workflows/example-09.yml
```

## The four you will actually use

| Trigger | The scenario |
|---|---|
| `push` + `branches: [main]` | it **landed**. This is the release path |
| `pull_request` + `types:` | somebody **proposes** a change, and this is the gate in front of main |
| `schedule` | the thing nobody remembers to do — a nightly dependency scan, a stale-branch report |
| `workflow_dispatch` | a human presses the button. Added last, used most |

**`push` and `pull_request` together runs a PR branch twice.** Usually not what you wanted:
scope `push` to `main` and let `pull_request` cover everything else.

**`schedule` is UTC and has no timezone field.** That is why "it ran an hour early" happens
every autumn.

**`pull_request` without `types:`** fires on `opened`, `synchronize` *and* `reopened`.

## "Merge" is not an event

There is no `on: merge` to subscribe to. **Merging a pull request is a push to the base
branch** — so a merge arrives as `push`, and the job in this example prints exactly that.

Once you see it, the release path stops being mysterious: `on: push` to `main` *is* "when
something is merged".

## The event does not have to come from GitHub

`repository_dispatch` is a run with **no commit behind it**. Anything that can make an
authenticated POST can start one:

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/repos/OWNER/REPO/dispatches \
  -d '{"event_type":"dataset-published",
       "client_payload":{"dataset":"orders","rows":128400}}'
```

The `client_payload` arrives verbatim as `github.event.client_payload.*`.

### The example worth naming out loud

**A feature store publishes a new slice of training data, and that starts the retraining
pipeline.** Nobody committed anything. The data changed, and the data is the input.

On the wording: *"retraining"* or *"continuous training"* is the semantically correct term —
**not** "continuous integration of data". CI integrates *code changes*; here the artefact
that changed is a **dataset**, and the pipeline that reacts is **continuous training**, the
third loop in an ML system alongside CI and CD. Saying "the data lake triggers CI" invites
the question *integrating what?*, and the honest answer is: nothing — it is training.

The same shape covers plenty that is not ML: a CMS publishing a page and rebuilding a static
site, a billing provider's webhook, another repository's pipeline saying *my part is done*.

## Try this

1. Open a PR into `main` and watch `pull_request` fire, then merge it and watch **`push`**
   fire — same change, two different events.
2. Fire the dispatch with the `curl` above and read `client_payload` in the log.
3. Add `push:` with no `branches:` and count how many times one PR branch builds.
