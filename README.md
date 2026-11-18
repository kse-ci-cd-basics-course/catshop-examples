# Catshop examples

| | |
|---|---|
| `.github/` | **the pipeline that really runs here** — and the shape to copy when you build your own |
| `app/` | **the thing being built**: Flask app, tests, Dockerfiles, Compose stacks |
| `pipeline/` | **the story** — one `ci.yml`, thirteen chapters, each caused by the pain of the one before |
| `topics/` | **one file per question** — triggers, cache, concurrency, retry, reuse, environments, artifacts |
| `by-hand/` | the same actions with the action **removed**, written as the HTTP it is |
| `terraform/` | **deploying it** — the same stack three ways, and the two axes they differ on: who runs Terraform, and who keeps the state |

`docs/` is not an example — it is the site GitHub Pages serves, and the only reason it is
here is that `topics/triggers-docs-pages.yml` subscribes to `docs/**` while the pipeline
subscribes to `app/**`, so one push matches exactly one of them.

Every folder but `.github/` and `docs/` is reading material. **GitHub reads workflows from
`.github/workflows/` at the repository root and nowhere else**, so a `ci.yml` anywhere else
is a text file. To run one, copy it in:

```bash
cp topics/triggers-on-main.yml .github/workflows/
git commit -am "demo: on main" && git push
```

## The pipeline that runs

```
pull request   test ─> image (build, do not push) ─> qa ─┐
               terraform fmt/validate/plan ─────────────┴─> apply  (waits for a person)
push to main   test ─> publish (ghcr.io, by digest) ─> qa ─> deploy (that digest, automatic)
```

| File | What it is |
|---|---|
| `pull-request.yml` | every pull request. A red suite cannot reach the build, nothing is published, and the terraform **plan lands in the run summary**. Applying from a pull request is possible and deliberate: the `pr-deploy` environment holds the job until somebody approves it |
| `main.yml` | a merge is a different event on a different commit, and the only one allowed to publish and to deploy. Tagged with the sha, never `latest`, labelled `org.opencontainers.image.revision`, and QA pulls **by digest** so what was checked is what shipped. The `deploy` job then hands that same digest to `terraform/3-gcp-github-oidc` and applies automatically — the merge was the decision. No stored key; the token is minted per run |
| `_build-and-test.yml` | a reusable workflow. It lives here because one is **only callable from `.github/workflows/`** — nothing triggers it |
| `actions/install-and-test` · `actions/qa` | composite actions: your own steps behind one `uses:`, on the caller's runner |

**It caches nothing, on purpose.** Get it correct, watch how long it takes, then read
`topics/cache-*` and `pipeline/10-cache-deps` and make it fast.

**No chapter before `pipeline/10` caches anything either**, so the nine minutes chapter 10
saves are a number you can watch happen rather than a claim.
