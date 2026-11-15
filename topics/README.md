# One file per question

Nothing here grows into the next file — these are not chapters. Each answers one question,
and the filename says which. Copy one into `.github/workflows/` to watch it run.

## `triggers-*` — which event, and therefore which commit

| File | What it shows |
|---|---|
| `triggers-on-main.yml` | the other half of a pull request: a merge arrives as a **push**, on a different commit, and only this one may deploy |
| `triggers-from-outside.yml` | the cron that hopes, replaced — `repository_dispatch`, and a run with no commit behind it |
| `triggers-message-routes.yml` | 02:00, production down. `build → qa → deploy`, and `[hotfix]` **skips the twenty-minute QA stage**. The `if:` on `deploy` is the lesson: `needs` hides an `&& success()`, so a skipped stage has to be allowed on purpose |
| `triggers-docs-pages.yml` | the other half of a `paths:` filter, and where `permissions:` earns its keep — `pages: write` to deploy, `id-token: write` so the deploy proves which run it is instead of holding a key |

**`paths:` is only worth teaching as a pair.** The finished pipeline subscribes to `app/**`,
this one to `docs/**`, and one push matches exactly one of them. Alone, a path filter looks
like extra typing.

## `cache-*` — four ways something moves, one rule for choosing

Same two jobs each time — `produce` and `consume` — with one mechanism swapped.

| File | What crosses | Promise |
|---|---|---|
| `cache-01-file-same-job.yml` | nothing leaves the job | a file is free **inside** one job, invisible outside it |
| `cache-02-artifact-between-jobs.yml` | **files** | it will be there, or the job fails |
| `cache-03-output-string.yml` | **one string** | it will be there, and it is a string even when it says `false` |
| `cache-04-cache-keyed.yml` | **files** | maybe. It is keyed, and it is allowed to be empty |

> **If a missing file should FAIL the job, it is an artifact. If it should only make the job
> SLOWER, it is a cache.**

A cache **does** cross jobs and runs, natively. The mistake is not "caches cannot cross" —
it is trusting one to. An image handed to a deploy job through a cache is green on Tuesday,
evicted by Thursday, and loads an empty tarball without a single red step.

- **Scope.** A cache belongs to a **ref**, not a workflow. Every workflow on that branch
  reads every cache on it; a pull request also reads the base branch, read-only; a fork's
  pull request gets the default branch, read-only. A restored cache is **untrusted input**,
  and a secret never goes in one.
- **Limits.** 10 GB per repository, evicted after 7 days unread. Not storage.
- **The exception somebody always asks about.** On a **self-hosted** runner files really do
  survive between jobs. That is the warm-disk trap, not a feature.

Next: `../pipeline/10-cache-deps` keyed properly across three OSes, `../pipeline/11-cache-layers`
for the **other** cache, `../pipeline/12-cache-testcontainers` for two numbers, and
`../by-hand/cache.yml` for the four curls the action is.

## `concurrency-*` — what is shared, and may it be cancelled?

| File | What is shared | Cancel? |
|---|---|---|
| `concurrency-01-one-deploy-per-environment.yml` | one **environment** | no — queue |
| `concurrency-02-one-suite-per-dataset.yml` | one **dataset** | no — queue |
| `concurrency-03-migration-main-only.yml` | one **schema** — and the group is not enough | no — queue, *and* filter the trigger |
| `concurrency-03b-migration-check-on-pr.yml` | nothing | **yes** — cancel freely |

> A concurrency group answers *how many at once?*. It cannot answer *who may do this at
> all?* — and that is the question a migration asks.

`concurrency.md` has the four cases in full: the pain, the group, and why `false`.

## `retry-*` — there is no automatic job retry

| File | Shows |
|---|---|
| `retry-01-bounded.yml` | a three-attempt loop with backoff that **fails at the end**, plus `timeout-minutes` at job and step level |
| `retry-02-attempt-aware.yml` | `GITHUB_RUN_ATTEMPT`, logging turned up only on a re-run, and why a re-run is cheap only if the cache exists |

- **Bounded, always.** A cap and a non-zero exit, or a broken dependency becomes a six-hour job.
- **A retry that eventually succeeds hides a flake.** Print the attempt into `$GITHUB_STEP_SUMMARY`.
- **Retry the network, not the test.** A retried test with no quarantine is a decorative suite.
- **"Re-run failed jobs" keeps `GITHUB_RUN_ID`** and increments `GITHUB_RUN_ATTEMPT`.
- **The cache save is a post-step that runs only on success**, so a job that never passed
  never saved, and every retry pays the full download.

## `reuse-*` — the two units, and the thing that is not one

| | composite action | reusable workflow |
|---|---|---|
| made of | **steps** | **jobs** |
| lives at | `.github/actions/<name>/action.yml` | `.github/workflows/<name>.yml` |
| called from | a `steps:` list | a job — `jobs.<id>.uses:` |
| runner | **the caller's** — same machine, same disk | **its own**, one per job, in parallel |
| the code | already checked out by the caller | it checks out itself; it shares nothing |
| can it fan out | no | yes — a `matrix` inside it, or at the call site |
| secrets | ordinary inputs, visible in the log unless masked | named, or `secrets: inherit` |

`reuse-both-units.yml` puts both on one screen. `reuse-anchors.yml` is YAML `&` and `*` —
the wrong fix, because an anchor never leaves its file. The reusable workflow itself is
`../.github/workflows/_build-and-test.yml`, and it cannot live here: that *is* the lesson.

## `environments-delivery-pipeline.yml` — one build, promoted

```
on main    build ─> image ─> sandbox ─> stage ─> production
on a PR    build ─> image ─> sandbox ─> stage            production is main only
```

`image` is the only job that builds and the only one that pushes; every environment after
it deploys **the same digest** — a tag can be moved between sandbox and production, a digest
cannot. QA runs *inside* each deploy job, through the one shared `qa` action with a
step-level `if:` on the environment, so a failed check stops the next environment. The gate
is the plain `needs:`, which carries an implicit `&& success()`. The approval on
`production` is a property of the environment, which is why no job mentions it.

`ENVIRONMENTS.md` is the setup: what to create, which variables and secrets live where, and
why a pipeline secret is not an application secret.

## `artifacts-what-a-run-leaves.yml` — evidence, not deliverables

| | an artifact | a registry |
|---|---|---|
| addressed by | this run's id | a name, from anywhere |
| lives | days or weeks, then deleted | until somebody deletes it |
| who reads it | a human on the run page, or a later job in the same run | anything that can pull, including production |
| good for | **evidence** — reports, logs, coverage | **deliverables** — the image you deploy |

A JUnit report, an HTML coverage report, and the image as a tarball `docker load`ed by a
**later job on a different machine** — what people reach for a registry to do, done without
publishing anything. `../.github/workflows/main.yml` publishes to GHCR instead, because that
image is a deliverable and a pull request's is not.
