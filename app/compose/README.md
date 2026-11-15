# The app's own containers, step by step

The same stack five times, one service or one setting added each time. **Step 1 is the
`Dockerfile` in `../`** — three of them:

| File | For |
|---|---|
| `Dockerfile` | the plain one. Read this first |
| `Dockerfile.optimized` | requirements copied and installed **before** the source, so an edit to `app.py` does not reinstall anything |
| `Dockerfile.multistage` | build stage thrown away, runtime stage small |

| Step | Adds | Note what is **not** there |
|---|---|---|
| `02-postgres` | a second service, `DATABASE_URL` is the whole application change | no volume — the rows die with the container |
| `03-volumes` | a named volume | the data now outlives `down`, and only `down -v` removes it |
| `04-wiremock` | the partner, stubbed — `catalog.json`, `catalog-slow.json`, `catalog-broken.json` | nothing real is called, and a broken partner is a 502 you can reproduce |
| `05-networks` | explicit networks | the same three services; only who can reach whom changed |

Each `compose.yaml` builds with `build: .`, so run one from beside the app:

```bash
cp app/compose/04-wiremock/compose.yaml app/
cp -r app/compose/04-wiremock/init-db app/compose/04-wiremock/partner app/
cd app && docker compose up --build
```
