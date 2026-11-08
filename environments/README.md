# environments — the delivery pipeline

`delivery-pipeline.yml` — `build → image → sandbox → stage → production` on `main`; a pull
request stops at stage. Each deploy job runs its own QA through the one shared action, and
production is reachable from `main` only.

```
on main    build ─> image ─> sandbox ─> stage ─> production
on a PR    build ─> image ─> sandbox ─> stage            production is main only
```

`image` is the only job that builds and the only one that pushes. It exports
`ghcr.io/<repo>@sha256:…`, so **every environment deploys the same bytes** — a tag can be
moved between sandbox and production, a digest cannot.

`../ENVIRONMENTS.md` has the setup: what to create in the repository, which variables and
secrets live where, and the three-bucket rule for deciding.
