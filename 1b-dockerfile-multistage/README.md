# Step 1b — multi-stage: the build toolchain does not ship

```bash
diff -u Dockerfile.single Dockerfile
```

Same app, same dependencies, same `requirements.txt`. The only change is **where the work happens**.

## Measure it first, explain it second

```bash
docker build -f Dockerfile.single -t ms:single .
docker build -f Dockerfile        -t ms:multi  .
docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' ms
```

Measured on this machine:

```
ms:single  684MB
ms:multi   253MB
```

**431 MB of difference, 2.7×, and not one line of application code changed.** Ask the room what is
in those 431 MB before answering.

```bash
docker run --rm ms:single sh -c 'gcc --version | head -1'
# gcc (Debian 14.2.0-19) 14.2.0

docker run --rm ms:multi sh -c 'gcc --version || echo "no gcc in the runtime image"'
# no gcc in the runtime image
```

A C compiler, its headers, and `libpq-dev` — shipped into production, on every node, on every deploy,
to do a job that finished at build time.

## The mechanic: a second `FROM` starts over

```dockerfile
FROM python:3.12-slim AS build      # stage 1 — named, so it can be referenced
…install compilers, build things…

FROM python:3.12-slim               # stage 2 — a BRAND NEW filesystem
COPY --from=build /opt/venv /opt/venv    # the one line that carries anything across
```

| Rule | Consequence |
|---|---|
| each `FROM` begins a new stage with a clean filesystem | nothing leaks forward by accident |
| **only `COPY --from=<stage>` crosses the boundary** | you have to *name* what ships. Default is nothing |
| the final stage is the image | earlier stages are build-time only. They are cached, not published |
| `AS build` is just a label | `COPY --from=0` works too; names survive reordering |

> One sentence to put on the slide: **nothing from a build stage ships unless you `COPY --from` it.**

## Why a *virtualenv* is what we copy

A build stage can produce anything — a jar, a Go binary, `node_modules`, a wheelhouse. For Python the
cleanest artifact is a venv, because it is **one self-contained directory**:

```dockerfile
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"      # ...in BOTH stages. Easy to forget in the second one.
```

Copy `/usr/lib/python3.12/site-packages` instead and you are reconciling system paths across two
images. Copy a venv and it is `cp -r`.

## The honest part, which matters more than the number

This app's dependencies ship as **prebuilt wheels** (`psycopg[binary]`), so it does not strictly need
a compiler at all — the 431 MB is a compiler we installed because projects really do, once, when one
dependency demanded it, and then never removed because taking it out might break the next build.

Multi-stage is **unavoidable** the moment any of these is true:

| Situation | What the build stage needs and the runtime does not |
|---|---|
| a C extension with no wheel for your platform | `build-essential`, headers, `pkg-config` |
| `psycopg[c]`, `mysqlclient`, `lxml`, `cryptography` from source | compilers + dev libraries |
| Node with native modules | `python3`, `make`, `g++`, a full `node_modules/.cache` |
| a compiled language | the **entire** toolchain. Go: 300 MB SDK → a 10 MB static binary |
| a frontend build | `npm ci` + 400 MB of `node_modules` → a folder of static files |

**So the rule is not "always use multi-stage". It is: measure, and if the build needs tools the
runtime does not, split it.** For a pure-Python app with wheels, a single `python:3.12-slim` stage is a
defensible choice — and you can only say that because you measured.

## Three more things this enables

```bash
# 1. build a stage on its own — the fastest way to debug the build half
docker build --target build -t ms:buildonly .

# 2. a test stage that never ships
#    FROM build AS test
#    RUN pip install pytest && pytest
#    docker build --target test .

# 3. stages build in PARALLEL when they do not depend on each other (BuildKit)
```

## It is still non-root

```bash
docker run --rm ms:multi id
# uid=10001(app) gid=10001(app)
```

Multi-stage and least privilege are independent wins and you want both: `USER` goes in the **final**
stage, after the `COPY --from`, because copying as a non-root user into `/opt` would fail.

## Carried forward

Steps 2–5 all use **this** `Dockerfile`, unchanged:

```bash
diff -u Dockerfile ../3-compose-postgres-volume/Dockerfile && echo "identical"
```

So every later diff is Compose only — the image stops changing here, and the rest of the lab is about
composition.
