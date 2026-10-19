# Step 1a — layers and the cache

**Files:** `Dockerfile`, five Dockerfile variants to measure against it, `cache.sh`, plus the
same `app.py`, `requirements.txt` and `.dockerignore` as every other step.

This step is a **measurement lab on step 1's image**, not a new application. It does not feed
into 1b: step 1b continues from step 1. The only difference between `1-dockerfile/Dockerfile`
and the `Dockerfile` here is one instruction, and you can see it:

```bash
diff -u ../1-dockerfile/Dockerfile Dockerfile
```

## The rule, stated correctly

Docker checks your instructions **in order, from the top**. Each one gets a cache key. While
the key matches, the existing layer is reused. At the **first** step whose key has changed the
cache is broken, and that step **and every step after it** are rebuilt — including steps whose
own content never changed.

> The cache is a **prefix** of your Dockerfile, not a collection of independent pieces.
> A hit on one step promises nothing about the next one.

So the ordering rule is not a style preference: **least-likely-to-change first,
most-likely-to-change last.** Source code goes at the bottom because you edit it fifty times a
day, and everything below an edit is lost.

## What goes into the key, and what does not

| Instruction | The key is built from | The trap |
|---|---|---|
| `FROM python:3.12-slim` | the resolved base image | a **tag is a mutable pointer**. Same text, different bytes next month — and then *every* step rebuilds. `FROM …@sha256:` pins it |
| `RUN pip install …` | the parent layer plus the **instruction text**, verbatim | Docker never looks at what the command *did*. `RUN git clone`, `RUN curl`, an unpinned `pip install` — identical text, different result, cache happily reused |
| `COPY` / `ADD` | the parent layer plus a checksum of the copied files' **contents, permissions and path** | the checksum is of the **build context**. A file outside the context is invisible; a file inside it is an input even if nothing imports it |

Two facts students always guess backwards, both measured below:

- **`touch` does nothing.** Modification time is not in the key (ACT 2).
- **`chmod` breaks it.** Permissions are (ACT 6).

## Run it

```bash
./cache.sh
```

Eight acts, each printing the build time, how many cacheable steps were `CACHED`, and which
steps had to be rebuilt. The script edits `app.py`, `requirements.txt` and `.dockerignore` on
purpose and restores them on exit, including on `Ctrl-C`.

## What it measures — Docker 29.8.2, five cacheable steps

| Act | What changed | Dependencies first (`Dockerfile`) | Source first (`Dockerfile.source-first`) |
|---|---|---|---|
| 1 | nothing | **0 s**, CACHED 5/5 | — |
| 2 | `touch app.py` | **0 s**, CACHED 5/5 | — |
| 3 | one line of `app.py` | **0 s**, CACHED 4/5 — only `COPY app.py` | **6 s**, CACHED 2/4 — **pip reran** |
| 4 | `echo "ha, got ya" > gotcha.txt` | **0 s**, CACHED 5/5 | **5 s**, CACHED 2/4 — **pip reran** |
| 5 | same file, now in `.dockerignore` | — | **1 s**, CACHED 4/4 |
| 6 | `chmod 600 requirements.txt` | **3 s**, CACHED 2/5 — **pip reran** | — |

**Act 4 is the moment.** `gotcha.txt` is not imported, not read, not referenced anywhere in the
application. It is one unused file sitting next to the code. The source-first build reinstalled
Flask, requests and psycopg because of it.

The mechanism, not the folklore: `COPY . .` takes the whole build context as its input, so the
new file changed that step's key, and `RUN pip install` sits **below** that step. Downstream of
a miss means rebuilt. The dependencies-first Dockerfile never saw the file at all — it copies
two files, by name.

**Act 5 is the fix, and it is one line.** Put the file outside the build context and it cannot
appear in any key. That is why `.dockerignore` is a build-performance file and not only a
hygiene file.

**Act 6 is the asymmetry.** `chmod` changed no byte of `requirements.txt`, and the install below
it still reran. Mode is in the key; mtime is not.

The script picks the mode from a pool instead of always using `600`, and the reason is worth
saying out loud: **BuildKit keeps every variant it has ever built**, not just the most recent
one. Flip the mode back to one you built an hour ago and the build hits the cache. Keys are
content-addressed, so a cache hit is a lookup, never a comparison against "last time".

## What the cache mount actually buys

`Dockerfile` keeps pip's wheel cache on the builder instead of in the image:

```dockerfile
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
```

Measured against `Dockerfile.pip-in-layer`, which is plain `pip install` with no flag and no
mount (ACT 7):

| Variant | The `pip install` layer | Where the wheel cache ends up |
|---|---|---|
| `pip install` | **42.5 MB** | **in the image**, shipped to every machine that pulls it, never read again |
| `pip install --no-cache-dir` (step 1) | **34.4 MB** | nowhere — thrown away, re-downloaded on every miss |
| `--mount=type=cache` (this step) | **34.4 MB** | on the builder: `docker buildx du` reports **8.126 MB** |

42.5 − 34.4 = **8.1 MB**, which is the cache mount, to the byte. The mount gives you the small
layer of `--no-cache-dir` **and** keeps the cache for the next build.

> **Honest about the time, too.** On *this* project the saving is under a second — three small
> wheels on a fast connection. Run ACT 7 and see for yourself. The same line on a
> `torch`/`numpy` image is worth minutes. **Measure before you believe an optimization
> matters**; that habit is worth more than the flag.

Note that `--no-cache-dir` is **absent** from this step's Dockerfile on purpose: it would
delete the directory we just mounted.

## A cleanup in a later layer frees nothing (ACT 8)

| Dockerfile | Instructions | Image |
|---|---|---|
| `Dockerfile.split-apt` | `apt-get update`, then `install`, then `rm -rf` — three `RUN`s | **649 MB** |
| `Dockerfile.one-layer` | the same three commands, one `RUN` | **611 MB** |

Same packages, same `rm`, **38 MB** apart. A layer can only **add** a filesystem diff; deleting
a file in a later layer records a deletion and keeps the bytes underneath. The same reasoning is
why `apt-get update` in its own layer is a bug: that layer gets reused and you install from a
stale index.

## Seeing the layers for yourself

**Watch the cache decide, step by step.** This is the one to put on the projector:

```bash
docker buildx build --progress=plain -t catshop:cache-good .
```

Every node prints its own line, and a reused one says `CACHED`. Run it twice.

**What the layers cost, once built:**

```bash
docker history catshop:cache-good --format '{{.Size}}\t{{.CreatedBy}}'
```

`ENV`, `USER`, `EXPOSE`, `HEALTHCHECK` and `CMD` are **0 B** — metadata, not filesystem. Only
`RUN` and `COPY` have a size.

**Interrogate the Dockerfile without building it:**

```bash
docker buildx build --call=targets .    # the stages, and which is the default
docker buildx build --call=outline .    # build args, secrets and mounts
docker buildx build --check .           # lint it; our Dockerfiles report no warnings
```

> `--call` is current buildx (**v0.37.2** here). Older material says `--print=outline`; that
> spelling resolves to nothing useful on this version. `--call=outline` prints an empty table
> when a Dockerfile declares no `ARG`s, which ours do not — add one and re-run to see it work.

**The cache itself, as stored on the builder:**

```bash
docker buildx du                                       # total build cache
docker buildx du --filter type=exec.cachemount         # just the pip wheel cache
docker buildx prune --filter type=exec.cachemount      # drop it, then rebuild cold
```

## The part that bites in CI, which is Lab 2's problem

A CI runner is a **fresh machine**. No previous build, so no local cache, however well you
ordered your instructions. Ordering buys you nothing there until you export the cache:

```bash
docker buildx build \
  --cache-to   type=registry,ref=<repo>:buildcache,mode=max \
  --cache-from type=registry,ref=<repo>:buildcache \
  -t <repo>:<sha> --push .
```

A **separate tag** for the cache, so pushing `:v1` never overwrites it, and `mode=max` to keep
intermediate stages — without it only the final stage's layers are exported, which for a
multi-stage build is almost nothing.

**What is missing:** nothing about the *image*. `catshop:cache-good` and `catshop:cache-bad` are
both **249 MB** — byte-for-byte the same packages, the same app, the same size. Everything on this
page bought **build time**, not a smaller artifact. Step 1b is where the image itself gets taken
apart: its single-stage variant is **684 MB**, because it ships a C compiler to production.
