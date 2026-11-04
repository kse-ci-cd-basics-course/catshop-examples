# The pipeline, one chapter at a time

`docker/` grows the **application**. This grows the **pipeline** — the same `ci.yml`,
ten times, one new segment each. Every chapter exists because the one before it hurt.

| | Chapter | The pain | What it adds | Lines |
|---|---|---|---|---|
| 01 | `01-pull-request` | the branch looked fine; main was red all weekend | **two real jobs on every pull request** — tests, then a docker build that has to start — and `needs` between them | 46 |
| 02 | `02-triggers` | it now runs on a README typo, on every branch | `branches` · `paths` · activity `types` · `workflow_dispatch` with inputs · `schedule` | 83 |
| 03 | `03-actions` | the same four steps pasted in three files, one still on 3.9 | `uses:` at a tag · pinning by sha · **your own composite action** · artifacts | 93 |
| 04 | `04-real` | two green ticks publish nothing | `needs` as a **graph** · job `outputs` · `matrix` · `concurrency` · `permissions` · publish only from `main` · a digest smoke test | 171 |
| 05 | `05-expressions` | the deploy went to `""` and reported success | `${{ }}` vs `$VAR` · `toJSON` · the empty-key trap · `$GITHUB_ENV`/`PATH`/`STEP_SUMMARY` · the rest of the `if:` family | 212 |
| 06 | `06-environments` | one repository secret was reachable from a workflow added on Tuesday | `env` at three levels · `vars` · `secrets` · `environment:` | 245 |
| 08 | `08-publish` | the image built, then the machine was deleted | `permissions: packages: write` · `docker/login-action` · `push:` as an **expression** so a PR builds and never publishes · the **digest** as a job output | 78 |
| 09 | `09-promote` | four environments, four builds, four different sets of bytes | **one build, promoted** — the digest from `08` passed down a ladder of environments, `environment:` gates, and production reachable only from `main` | 77 |
| 10 | `10-cache-deps` | nine of the nine minutes were downloads, forty-eight times over | `actions/cache` · `key` vs `restore-keys` · `hashFiles` · `pip cache dir` · a per-OS path via matrix `include` | 58 |
| 11 | `11-cache-layers` | the dependency cache did nothing for the docker build | the **other** cache — `cache-from`/`cache-to: type=gha` · `mode=max` vs the default `min` · `scope` per matrix row · the registry backend · Dockerfile **order** | 103 |
| 12 | `12-cache-testcontainers` | the integration suite pulls Postgres and rebuilds the image on every single run | buildx `outputs: type=docker` · `docker save`/`load` across a job · `cache-from`/`cache-to: type=gha` · `mode=max` · `CATSHOP_IMAGE` | 77 |
| 13 | `13-coverage-gate` | the coverage report has gone into an artifact nobody opens for three weeks | `download-artifact` across a matrix · `merge-multiple` · a `--fail-under` that fails the job · the check branch protection names | 68 |
| 07 | `07-reusable` | four repositories run the same test-and-build pair | **a reusable workflow** — `workflow_call`, `jobs.<id>.uses:`, typed inputs, `secrets: inherit`, outputs that come back | 199 |

**The diff is the lesson:**

```bash
diff -u pipeline/03-actions/ci.yml pipeline/04-real/ci.yml
```

## The two shared things, and why there are two

| | composite action | reusable workflow |
|---|---|---|
| made of | **steps** | **jobs** |
| lives at | `.github/actions/<name>/action.yml` | `.github/workflows/<name>.yml` |
| called from | a `steps:` list — `uses: ./.github/actions/x` | a job — `jobs.<id>.uses: ./.github/workflows/x.yml` |
| runner | **the caller's** — same machine, same disk | **its own**, one per job, in parallel |
| the code | already checked out by the caller | it checks out itself; it shares nothing |
| can it fan out | no | yes — a `matrix` inside it, or at the call site |
| secrets | ordinary inputs, visible in the log unless masked | named, or `secrets: inherit` |

Chapter 03 introduces the first, chapter 07 the second. `install-and-test` stays a
composite action **inside** the reusable workflow, which is the normal arrangement: steps
compose into a job, jobs compose into a workflow.

## None of these are running

GitHub reads workflows from **`.github/workflows/` at the repository root** and nowhere
else. Everything in here is reading material — a `ci.yml` in a subfolder is a text file.

`.github/workflows/ci.yml` is chapter 07, the end state. To demo an earlier one:

```bash
cp pipeline/02-triggers/ci.yml .github/workflows/ci.yml
git commit -am "chapter 2" && git push
```

## The publish, cache and gate chapters are out of sequence on purpose

`08`, `09`, `10`, `11`, `12` and `13` are numbered for where they belong in the story, not for when they were
written. `10`–`13` are also the only chapters that are **measured** rather than read:

```bash
# the whole point of 12 is two numbers, so run it twice
gh workflow run integration.yml && gh run watch     # cold
gh workflow run integration.yml && gh run watch     # warm
```

`12` makes all four cache-or-artifact decisions in one file, and the comment block at the
top lists them with the reason for each. The rule they come from: **if a missing file should
fail the job it is an artifact; if it should only make the job slower it is a cache.**

`ci-base-app/tests/test_integration_db.py` is the test `12` measures. It reads
`CATSHOP_IMAGE` rather than building an image, and it deliberately does **not** use
Testcontainers' `reuse` — both for the same reason: a test that rebuilds makes a cold run
and a warm run take the same time, which is how people conclude that caching does nothing.

## Concurrency is a folder of its own

`../concurrency/` — four files, one use case each, with a README section per case. They are
not chapters because none of them grows into the next: each is a different answer to
*"what is shared, and may it be cancelled?"*, and `03` is the case where a concurrency
group **is not the answer** and a path filter is.

## `../cache/` comes before chapter 10

Four files, the same two jobs each time, one mechanism swapped: a file inside one job, an
artifact, an output, a cache. It exists because the chapters below use all four and the
choice between them is one sentence — *if a missing file should FAIL the job it is an
artifact; if it should only make the job SLOWER it is a cache.* `../retry/` sits beside
it: no automatic job retry exists, so a retry is a bounded loop you wrote, and
`GITHUB_RUN_ATTEMPT` is how a job knows it is in one.

## `../by-hand/` is the same material with the actions removed

Five files that write out what `checkout`, `login-action`, `buildx`, `cache` and
`upload-artifact` are doing — `git init` and a token, `--password-stdin` and a base64
blob, one long `docker buildx build`, `sha256sum` plus `tar`, and a zip behind an API.
Each has a `the-action:` job and a `by-hand:` job so the two logs can be read side by
side. `../by-hand/README.md` has the table and the two honest caveats.

## The four that are not chapters

`08-on-main.yml`, `09-from-outside.yml`, `10-message-routes.yml`, `11-anchors.yml` and
`12-docs-pages.yml` sit
in `.github/workflows/` as files of their own. Each is a **different subscription**, not a
bigger pipeline — folding them into `ci.yml` would make it longer without making it
better.

`08-on-main.yml` is the other half of chapter 01: a pull request and a merge are two
events, two files and **two different commits**.

`12-docs-pages.yml` is the other half of chapter 02's `paths:` filter. `ci.yml` takes
`ci-base-app/**`, the docs workflow takes `docs/**`, and one push matches exactly one of
them — which is the only arrangement in which a path filter is obviously worth having. It
is also where `permissions:` stops being ceremony: `pages: write` to deploy, and
`id-token: write` so the deploy can prove which run it is instead of holding a key.
