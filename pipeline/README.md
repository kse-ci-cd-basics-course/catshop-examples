# One pipeline, thirteen chapters

The same `ci.yml`, one new segment each time. Every chapter exists because the one before
it hurt.

| | Chapter | The pain | What it adds | Lines |
|---|---|---|---|---|
| 01 | `01-pull-request` | the branch looked fine; main was red all weekend | **two real jobs on every pull request** — tests, then a docker build that has to start — and `needs` between them | 46 |
| 02 | `02-triggers` | forty runs a day: a README typo, every branch | `branches` · `paths` · activity `types` · `workflow_dispatch` with inputs · `schedule` | 83 |
| 03 | `03-actions` | the same four steps pasted in three files, one still on 3.9 | `uses:` at a tag · pinning by sha · **your own composite action** · artifacts | 93 |
| 04 | `04-real` | two green ticks publish nothing | `needs` as a **graph** · job `outputs` · `matrix` · `concurrency` · `permissions` · publish only from `main` · a digest smoke test | 171 |
| 05 | `05-expressions` | the deploy went to `""` and reported success | `${{ }}` vs `$VAR` · `toJSON` · the empty-key trap · `$GITHUB_ENV`/`PATH`/`STEP_SUMMARY` · the rest of the `if:` family | 212 |
| 06 | `06-environments` | one repository secret was reachable from a workflow added on Tuesday | `env` at three levels · `vars` · `secrets` · `environment:` | 245 |
| 07 | `07-reusable` | four repositories run the same test-and-build pair | **a reusable workflow** — `workflow_call`, `jobs.<id>.uses:`, typed inputs, `secrets: inherit`, outputs that come back | 199 |
| 08 | `08-publish` | the image built, then the machine was deleted | `permissions: packages: write` · `docker/login-action` · `push:` as an **expression** so a PR builds and never publishes · the **digest** as a job output | 78 |
| 09 | `09-promote` | four environments, four builds, four different sets of bytes | **one build, promoted** — the digest from `08` down a ladder of environments, `environment:` gates, production reachable only from `main` | 77 |
| 10 | `10-cache-deps` | nine of the nine minutes were downloads, forty-eight times over | `actions/cache` · `key` vs `restore-keys` · `hashFiles` · `pip cache dir` · a per-OS path via matrix `include` | 58 |
| 11 | `11-cache-layers` | the dependency cache did nothing for the docker build | the **other** cache — `cache-from`/`cache-to: type=gha` · `mode=max` vs the default `min` · `scope` per matrix row · the registry backend · Dockerfile **order** | 103 |
| 12 | `12-cache-testcontainers` | the integration suite pulls Postgres and rebuilds the image every run | buildx `outputs: type=docker` · `docker save`/`load` across a job · `type=gha` · `mode=max` · `CATSHOP_IMAGE` | 77 |
| 13 | `13-coverage-gate` | the coverage report goes into an artifact nobody opens for three weeks | `download-artifact` across a matrix · `merge-multiple` · a `--fail-under` that fails the job · the check name branch protection takes | 68 |

**No chapter before 10 caches anything, on purpose.** Chapters 01–09 download the same
packages and rebuild the same layers every run, so the nine minutes in chapter 10 are a
number the room has watched happen rather than a claim. Lifting one of these into a real
pipeline? Add the cache back.

**The diff is the lesson:**

```bash
diff -u pipeline/03-actions/ci.yml pipeline/04-real/ci.yml
```

**None of these run.** A `ci.yml` in a subfolder is a text file; `../.github/workflows/`
holds the finished pipeline. Copy a chapter in beside it to demo it.

**10–13 are measured rather than read** — run one twice:

```bash
gh workflow run integration.yml && gh run watch     # cold
gh workflow run integration.yml && gh run watch     # warm
```

`12` makes all four cache-or-artifact decisions in one file and the comment block at the top
gives the reason for each. The rule: **if a missing file should fail the job it is an
artifact; if it should only make the job slower it is a cache.** The test it measures is
`../app/tests/test_integration_db.py`, which reads `CATSHOP_IMAGE` instead of building an
image and deliberately does **not** use Testcontainers' `reuse` — both so that a cold run
and a warm run do not come out the same, which is how people conclude caching does nothing.

Chapter 03 introduces the composite action, chapter 07 the reusable workflow, and
`install-and-test` stays a composite action **inside** the reusable workflow — steps compose
into a job, jobs compose into a workflow. The table that separates the two is in
`../topics/README.md`.
