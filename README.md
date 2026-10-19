# catshop — the reference examples

Seven directories. Each one **runs on its own**, and each differs from the previous by exactly the
thing it teaches. Read them in order, `diff` them against each other, run them.

This repo is **reference material you read**. Your graded work goes in your own lab repository.

## The application

One small Flask app, **byte-identical in all seven directories** (`md5 */app.py` to prove it). Three
endpoints, deliberately chosen to depend on three different kinds of thing:

| Endpoint | Depends on | Appears in |
|---|---|---|
| `GET /health` | nothing | step 1 |
| `GET /visits` | our own state — a file, then a database | step 1, then step 2 |
| `GET /price/<sku>` | an API we do not own | step 4 |

The app never learns about volumes, networks or stubs. **Its composition does.** That is the whole
argument of this repo.

## The seven steps

| Step | Directory | Adds | The moment |
|---|---|---|---|
| 1 | `1-dockerfile/` | `Dockerfile`, `.dockerignore` | ten instructions, each with a consequence. `EXPOSE` publishes nothing |
| 1a | `1a-cache/` | a cache mount, five variants to measure, `cache.sh` | one **unused** file in the folder, and every dependency reinstalls. **6 s → 0 s** on the same edit |
| 1b | `1b-dockerfile-multistage/` | a second `FROM` | **684 MB → 253 MB.** The single-stage image ships a C compiler to production |
| 2 | `2-compose-postgres-no-volume/` | `compose.yaml`, `init-db/` | a real database — and `down`/`up` **still loses every row** |
| 3 | `3-compose-postgres-volume/` | a named volume | three lines of YAML, and the data survives |
| 4 | `4-compose-wiremock-partner/` | a `partner` service + stubs | a 500 and a 5-second delay, on demand |
| 5 | `5-compose-networks-internal/` | `networks:` on every service | the database and the stub can reach **nothing** |

Each directory has its own `README.md` with the commands, the expected output, and why.

## Running a step

**Steps 1 and 1a are a single image — no Compose:**

```bash
cd 1-dockerfile
docker build -t catshop:step1 .
docker run -d --name step1 -p 8080:8080 catshop:step1
curl localhost:8080/health
docker rm -f step1
```

**Step 1a is measured, not served.** It builds the app six ways and prints what the cache did;
nothing to `curl`:

```bash
cd 1a-cache
./cache.sh                                        # eight acts, with timings
docker buildx build --progress=plain -t catshop:cache-good .   # watch each node decide
```

**Steps 2 to 5 use Compose:**

```bash
cd 3-compose-postgres-volume
cp .env.example .env          # .env is git-ignored and must stay that way
docker compose up -d --build
curl localhost:8080/visits
docker compose down           # add -v to delete the volume too
```

> **One at a time.** Every step that runs a container publishes host port `8080`. Bring the previous step down first, or
> `docker ps --filter publish=8080` will tell you who is holding it.

## Seeing what each step changed

The diff *is* the lesson. Exclude the README — the prose differs on every line and would bury the
three lines of YAML that matter:

```bash
diff -ru -x README.md -x .env 2-compose-postgres-no-volume 3-compose-postgres-volume
```

Step 2 → 3 comes out as **one mount plus one `volumes:` key**. That is persistence, entire.

Step 1 → 1a is **one instruction**, and it is the only thing that step changes:

```bash
diff -u 1-dockerfile/Dockerfile 1a-cache/Dockerfile
```

1a is a measurement lab on step 1's image and is deliberately **not** in the lineage: step 1b
continues from step 1, with `--no-cache-dir` rather than the cache mount.

For step 1b, compare inside the folder instead — the same dependencies built two ways:

```bash
cd 1b-dockerfile-multistage && diff -u Dockerfile.single Dockerfile
```

The image stops changing at 1b. Steps 2–5 all carry that same multi-stage `Dockerfile`:

```bash
diff -u 1b-dockerfile-multistage/Dockerfile 5-compose-networks-internal/Dockerfile && echo identical
```

**So every diff from 1b onwards is Compose, not code.**

## Project names are pinned

Each `compose.yaml` sets a top-level `name:` (`catshop-step2` … `catshop-step5`). Without it the
project name defaults to the directory name, so volumes and networks would be called
`3-compose-postgres-volume_pgdata` and would move the moment a folder was renamed. Pinned, they are
`catshop-step3_pgdata` and `catshop-step5_partnernet`, and every command in the step READMEs keeps
working.

## Verified, not assumed

Every claim in these READMEs was executed on a real daemon (Docker 29.8.2):

| Check | Result |
|---|---|
| step 2 — `visits` 1, 2, then **1** after `down`/`up` | data loss reproduces |
| step 2 — `docker diff` shows **no** `/var/lib/postgresql/data`; the mount is an **anonymous volume** (hex name), orphaned by `down` | the real mechanism, not the folklore |
| step 3 — `visits` 1, 2, then **3** after `down`/`up` | data survives |
| step 4 — `/price/MK-II` → 200 · `/price/BOOM-1` → **502** · `/price/SLOW-1` → **502 after 2.017 s** | all three failure modes on demand |
| step 5 — db unreachable from host · app→db by name ok · db→internet no route · partner→internet no route | isolation holds |
| step 1b — `ms:single` **684 MB** with `gcc 14.2.0`; `ms:multi` **253 MB** with no gcc | 2.7×, same app |
| step 1a — one line of `app.py` edited: dependencies-first **0 s** (4/5 cached), source-first **6 s** (2/4, pip reran) | ordering is the whole of build performance |
| step 1a — one **unused** file created: source-first **5 s**, dependencies-first **0 s** (5/5) | the build context is an input, whether you use the file or not |
| step 1a — `touch` leaves the cache intact; `chmod 600` breaks it and reruns the install | mtime is not in the key, mode is |
| step 1a — `pip install` layer **42.5 MB** in-image vs **34.4 MB** with a cache mount holding **8.126 MB** | the difference is the wheel cache, to the byte |
| step 1a — `split-apt` **649 MB** vs `one-layer` **611 MB** | a later `rm` frees nothing |

## Secrets

`.env` is git-ignored in this repo and must stay that way. `.env.example` carries a placeholder
(`POSTGRES_PASSWORD=change-me-locally`) and is the only one of the two that is ever committed.
This applies to your own lab repository too, and it is checked.
