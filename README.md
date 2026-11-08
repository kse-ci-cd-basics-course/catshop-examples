# Catshop Examples

Two kinds of thing live here, and the difference matters:

| | What it is |
|---|---|
| **`.github/workflows/`** | **the finished pipeline.** The one that actually runs in this repository, and the shape lab 2 asks for: pull request → test → build → QA, and on `main` the same plus a push to GHCR and QA against what was published |
| **everything else** | **examples**, one folder per topic. Nothing in them runs until you copy it into `.github/workflows/` — GitHub reads workflows from the repository root and nowhere else |

---

## The finished pipeline — `.github/workflows/`

```
pull request   test ─> image (build, do not push) ─> qa
push to main   test ─> publish (ghcr.io, by digest) ─> qa against what was published
```

| File | What it is |
|---|---|
| `pull-request.yml` | every pull request. A red suite cannot reach the build; nothing is published |
| `main.yml` | a merge is a different event on a different commit, and the only one allowed to publish. Tags with the sha, never `latest`, labels `org.opencontainers.image.revision`, and QA pulls the image **by digest** so what was checked is what shipped |

Both use the composite actions in `.github/actions/` — `install-and-test` and `qa`.
`_build-and-test.yml` sits beside them because a **reusable workflow is only callable from
`.github/workflows/`**; nothing triggers it, and `reuse/` explains it.

**Neither one caches anything, on purpose.** That is the lab-2 shape: get it correct, watch
how long it takes, then read `cache/` and `pipeline/10-cache-deps` and make it fast. Adding
a cache is a few lines, and it is a bonus section in the lab rather than a requirement.

---

## The examples, by topic

| Folder | What it covers |
|---|---|
| `pipeline/` | **one team's pipeline over a term** — the same `ci.yml`, thirteen times, one new segment each, every chapter caused by the pain of the one before |
| `triggers/` | which event, and therefore which run: a merge, a dispatch from outside, `[hotfix]` routing, a docs-only path filter |
| `cache/` | the four ways something moves between steps, jobs and runs — file, artifact, output, cache — and the one rule for choosing |
| `retry/` | there is no automatic job retry. `GITHUB_RUN_ATTEMPT`, and a loop you wrote with a cap on it |
| `concurrency/` | one use case per file: one deploy per environment, one suite per dataset, and the case where a concurrency group is **not** the answer |
| `reuse/` | the two units — a composite action made of steps, a reusable workflow made of jobs — and YAML anchors, which are neither |
| `environments/` | the delivery pipeline: sandbox → stage → production, one build promoted by digest, approval as a property of the environment |
| `artifacts/` | what a run leaves behind: reports, coverage, an image as a tarball handed to a later job |
| `by-hand/` | every action above with the action removed, written as the HTTP it is: the cache service in four curls, a GHCR push in five, the layer cache found in the store it lives in |
| `docker/` | the application's own containers — Dockerfiles, Compose, volumes, WireMock, networks |
| `ci-base-app/` | the small Flask app everything else is about: `/health`, `/ready`, `/visits`, `/price` |

```
pipeline/01-pull-request   the branch looked fine; main was red all weekend
        /02-triggers       forty runs a day
        /03-actions        three copies, already drifting
        /04-real           "we have to actually ship it"
        /05-expressions    deployed to nothing
        /06-environments   qa credentials in production
        /07-reusable       the same two jobs, in four repositories
        /08-publish        the image built, then the machine was deleted
        /09-promote        four environments, four builds, four different bytes
        /10-cache-deps     nine of the nine minutes were downloads
        /11-cache-layers   and none of that helped the docker build
        /12-cache-testcontainers   Postgres pulled and the image rebuilt, every run
        /13-coverage-gate  the coverage number nobody was blocking on
```

**No chapter before 10 caches anything**, so the nine minutes in chapter 10 are a number
the room has watched happen rather than a claim.

Each folder has its own `README.md`. To run any example:

```bash
cp triggers/on-main.yml .github/workflows/
git commit -am "demo: on main" && git push
```

---

## Four ideas the examples exist to carry

### The delivery pipeline is one build, promoted

`environments/delivery-pipeline.yml`. `image` is the only job that builds and the only one
that pushes; every environment after it deploys **the same digest**. The QA run lives
*inside* each deploy job — deploy, then check, in one job — so a failed check makes that
job red and the next environment never starts. The gate is the plain `needs:`, which
carries an implicit `&& success()`.

**One shared QA action, not three jobs.** `.github/actions/qa` takes the environment as an
input and a step-level `if:` decides the depth: smoke everywhere, the contract pack
anywhere that is not production, end-to-end on stage, read-only on production — because no
test writes to production.

```yaml
      - uses: ./.github/actions/qa
        with:
          environment: stage
          host: ${{ vars.APP_HOST }}
```

**`needs:` also draws the run graph**, one arrow per entry. Pass values down the chain
instead of reaching back two jobs for an output: reading an output costs an edge, and the
picture turns into a cat's cradle.

### A pipeline secret is not an application secret

The deploy steps are identical in all three environments. `vars.APP_HOST` resolves to a
different host each time, and no job has an `if:` on an environment name.

What is **not** in there is as much of the lesson: no `DATABASE_URL`, no payment key, no
signing key. Those live in a secret manager, and the **running application** fetches them
at startup with an identity the platform gives it. The pipeline passes only the *address*.

> **A pipeline secret is a credential for deploying. An application secret is a credential
> for running, and the pipeline should never see it.**

The approval gate on `production` is a property of the environment, not a step — which is
why nothing in the file mentions it.

### An artifact is not a registry

| | an artifact | a registry |
|---|---|---|
| addressed by | this run's id | a name, from anywhere |
| lives | days or weeks, then deleted | until somebody deletes it |
| who reads it | a human on the run page, or a later job in the same run | anything that can pull, including production |
| good for | **evidence** — reports, logs, coverage | **deliverables** — the image you deploy |

`artifacts/what-a-run-leaves.yml` produces all three and makes the distinction do work: the
image is written to a tarball with `outputs: type=docker,dest=…`, uploaded, and
`docker load`ed by a **later job on a different machine** — the thing people reach for a
registry to do, done without publishing anything. `.github/workflows/main.yml` publishes to
GHCR instead, because that image is a deliverable and a pull request's is not.

### `paths:` is only worth teaching as a pair

The finished pipeline subscribes to `ci-base-app/**`; `triggers/docs-pages.yml` subscribes
to `docs/**`. One push matches exactly one of them, and a typo in the runbook no longer
sits through a docker build. Shown on its own, a path filter just looks like extra typing.

`triggers/docs-pages.yml` is also the honest `permissions:` example — publishing to Pages
needs `pages: write` and `id-token: write`, and the second is OIDC where you can see it:
the deploy holds no key, it asks GitHub to vouch for the run.

## `.github/actions/`

`install-and-test` and `qa` — both **composite actions**: your own steps, behind one
`uses:`, running on the caller's machine and the caller's disk. The finished pipeline uses
both; `pipeline/03-actions` onwards and `reuse/both-units.yml` show how they are built.
