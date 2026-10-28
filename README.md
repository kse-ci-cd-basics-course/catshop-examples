# Catshop Examples

This repository contains reference material for learning CI/CD with Docker and GitHub Actions.

## Base Application
Located in `ci-base-app/`, it is a small Flask application with three endpoints (`/health`, `/visits`, `/price`).

## Docker Examples
Located in `docker/`, each example builds on the base application to demonstrate different features:

- `01-dockerfile`: Demonstrates base, multi-stage, and optimized Dockerfiles.
- `02-compose-postgres`: Basic database integration (ephemeral).
- `03-compose-volumes`: Database with persistent storage.
- `04-compose-wiremock`: Integrating a third-party partner service.
- `05-compose-networks`: Isolated internal networks.

## GitHub Actions

One team's pipeline over one term. `pipeline/` holds the chapters — the same `ci.yml`,
seven times, one new segment each, and every chapter exists because the one before it
hurt. `pipeline/README.md` has the table, the diff commands, and the composite-action
versus reusable-workflow comparison.

```
pipeline/01-pull-request   the branch looked fine; main was red all weekend
        /02-triggers       forty runs a day
        /03-actions        three copies, already drifting
        /04-real           "we have to actually ship it"
        /05-expressions    deployed to nothing
        /06-environments   qa credentials in production
        /07-reusable       the same two jobs, in four repositories
```

`.github/workflows/` is what actually runs — **the repository root is the only place
GitHub reads**:

| File | What it shows |
|---|---|
| `ci.yml` | chapter 07, the end state. Copy an earlier chapter over it to demo one |
| `_build-and-test.yml` | the **reusable workflow**: made of jobs, called with `jobs.<id>.uses:`, its own runners and its own checkout |
| `08-on-main.yml` | the other half of chapter 01. A merge is not an event — it arrives as a push, in a different file, on a different commit, and only this one may deploy |
| `09-from-outside.yml` | the cron that hopes, replaced — `repository_dispatch` and a run with no commit behind it |
| `10-message-routes.yml` | 02:00, production down. `build → qa-testing → deploy`, and `[hotfix]` **skips the twenty-minute qa stage** and deploys. The `if:` on `deploy` is the lesson: `needs` hides an `&& success()`, so a skipped stage has to be allowed on purpose |
| `14-environments.yml` | **the delivery pipeline.** `build → sandbox → qa-sandbox → stage → qa-stage → prod → qa-prod` on main; on a pull request it stops after the sandbox, and only if you label it. `ENVIRONMENTS.md` has the setup |
| `11-anchors.yml` | `&` defines, `*` repeats — and the wrong fix for chapter 03, because an anchor never leaves its file |
| `15-reuse.yml` | **both units of reuse in one screen** — a composite action used as a step, a reusable workflow used as a job |
| `13-artifacts.yml` | **what a run leaves behind** — a JUnit report, an HTML coverage report, and the image itself as a tarball, handed to a later job without publishing anything |
| `12-docs-pages.yml` | the **other half of the path filter**: a docs edit never runs the tests, and republishing to GitHub Pages by hand is where `permissions:` finally earns its keep |

### The delivery pipeline

```
on main    build ─> sandbox ─> qa-sandbox ─> stage ─> qa-stage ─> prod ─> qa-prod
on a PR    build ─> sandbox ─> qa-sandbox      (only with the deploy:sandbox label)
```

Every gate is a plain `needs:`. It carries an implicit `&& success()`, so a red `qa-sandbox`
stops `stage` before it starts — the same default that is a nuisance in `10-message-routes.yml`
and exactly what is wanted here. Each environment runs **its own** test pack against **its own**
host, and production is tested too: `qa-prod` runs *after* the deploy, read-only.

The sandbox deploy on a pull request is opt-in — add the `deploy:sandbox` label. That is what
`types: [labeled]` is for.

### A pipeline secret is not an application secret

The deploy steps are identical in all three environments. `vars.APP_HOST` resolves to a
different host each time, and no job has an `if:` on an environment name.

What is **not** in there is as much of the lesson: no `DATABASE_URL`, no payment key, no signing
key. Those live in a secret manager, and the **running application** fetches them at startup
with an identity the platform gives it. The pipeline passes only the *address* —
`VAULT_ROLE` — so a leaked log or a careless `echo` cannot give away the database.

> **A pipeline secret is a credential for deploying. An application secret is a credential for
> running, and the pipeline should never see it.**

The approval gate on `production` is a property of the environment, not a step — which is why
nothing in the file mentions it.

### An artifact is not a registry

| | an artifact | a registry |
|---|---|---|
| addressed by | this run's id | a name, from anywhere |
| lives | days or weeks, then deleted | until somebody deletes it |
| who reads it | a human on the run page, or a later job in the same run | anything that can pull, including production |
| good for | **evidence** — reports, logs, coverage, a build output under review | **deliverables** — the image you deploy |

`13-artifacts.yml` produces all three and makes the distinction do work: on a pull request the
image is written to a tarball with `outputs: type=docker,dest=…`, uploaded, and `docker load`ed
by a **later job on a different machine** — the thing people reach for a registry to do, done
without publishing anything. `ci.yml` publishes to GHCR instead, because that image is a
deliverable and a pull request's is not.

### `paths:` is only worth teaching as a pair

`ci.yml` subscribes to `ci-base-app/**`; `12-docs-pages.yml` subscribes to `docs/**`. One push
matches exactly one of them, and a typo in the runbook no longer sits through a docker build.
Showing the filter on its own just looks like extra typing.

`12-docs-pages.yml` is also the honest `permissions:` example — publishing to Pages needs
`pages: write` and `id-token: write`, and the second one is OIDC where you can see it: the deploy
holds no key, it asks GitHub to vouch for the run.

### `.github/actions/install-and-test/`

A **composite action**: your own steps, behind one `uses:`, running on the caller's
machine. Chapters 03–06, the reusable workflow and `10-message-routes.yml` all use it.
