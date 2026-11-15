# Catshop examples

| | |
|---|---|
| `.github/` | **the pipeline that really runs here** — and the shape lab 2 asks for |
| `app/` | **the thing being built**: Flask app, tests, Dockerfiles, Compose stacks |
| `pipeline/` | **the story** — one `ci.yml`, thirteen chapters, each caused by the pain of the one before |
| `topics/` | **one file per question** — triggers, cache, concurrency, retry, reuse, environments, artifacts |
| `by-hand/` | the same actions with the action **removed**, written as the HTTP it is |
| `docs/` | the two pages `topics/triggers-docs-pages.yml` deploys |

Every folder but `.github/` is reading material. **GitHub reads workflows from
`.github/workflows/` at the repository root and nowhere else**, so a `ci.yml` anywhere else
is a text file. To run one, copy it in:

```bash
cp topics/triggers-on-main.yml .github/workflows/
git commit -am "demo: on main" && git push
```

## The pipeline that runs

```
pull request   test ─> image (build, do not push) ─> qa
push to main   test ─> publish (ghcr.io, by digest) ─> qa against what was published
```

| File | What it is |
|---|---|
| `pull-request.yml` | every pull request. A red suite cannot reach the build; nothing is published |
| `main.yml` | a merge is a different event on a different commit, and the only one allowed to publish. Tagged with the sha, never `latest`, labelled `org.opencontainers.image.revision`, and QA pulls **by digest** so what was checked is what shipped |
| `_build-and-test.yml` | a reusable workflow. It lives here because one is **only callable from `.github/workflows/`** — nothing triggers it |
| `actions/install-and-test` · `actions/qa` | composite actions: your own steps behind one `uses:`, on the caller's runner |

**It caches nothing, on purpose.** That is the lab-2 shape: get it correct, watch how long
it takes, then read `topics/cache-*` and `pipeline/10-cache-deps` and make it fast.

**No chapter before `pipeline/10` caches anything either**, so the nine minutes chapter 10
saves are a number the room has watched happen rather than a claim.
