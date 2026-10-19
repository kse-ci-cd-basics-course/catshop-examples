# Step 2 — add Postgres, and lose the data

```bash
diff -u ../1-dockerfile/Dockerfile Dockerfile    # identical. The image did not change.
```

**New:** `compose.yaml`, `init-db/01-schema.sql`, `.env.example`.
**The app change is one environment variable** — `DATABASE_URL` moves the counter from a file to
Postgres. Same image as step 1.

## Three things in this file worth naming

| Line | Why it is there |
|---|---|
| `DATABASE_URL: …@db:5432/…` | `db` is a **hostname**. It resolves because Compose created a network and registered the service name. Step 5 takes this away to show what it was doing |
| `healthcheck` + `condition: service_healthy` | `depends_on` alone waits for the **container to start**, not for Postgres to accept connections. Try removing the condition and read `docker compose logs app` |
| `./init-db:/docker-entrypoint-initdb.d:ro` | schema on first boot only — **on an empty data directory** |

## Run it, then break it

```bash
cp .env.example .env
docker compose up -d --build
curl localhost:8080/visits        # {"store":"postgres","visits":1}
curl localhost:8080/visits        # {"store":"postgres","visits":2}
```

Confirm it really is in the database, not a file:

```bash
docker compose exec db psql -U shop -d shop -c 'select count(*) from visits;'
#  count
# -------
#      2
```

Now the most ordinary command in the world:

```bash
docker compose down
docker compose up -d
curl localhost:8080/visits        # {"store":"postgres","visits":1}   <-- THE ROWS ARE GONE
```

**Nothing errored. Nothing warned. Nobody was told.** A "real database" bought exactly zero
durability, because `volumes:` has no entry for the data directory.

## Where the data actually went — and it is not where people say

The usual explanation is "it was in the container's writable layer". **Check it instead of
repeating it.** `docker diff` lists every path a container changed relative to its image:

```bash
docker diff "$(docker compose ps -q db)"
# C /run
# C /run/postgresql
# A /run/postgresql/.s.PGSQL.5432
# A /run/postgresql/.s.PGSQL.5432.lock
```

Four paths, and **not one of them is `/var/lib/postgresql/data`**. A whole database was written and
`docker diff` cannot see it. So where is it?

```bash
docker image inspect postgres:16-alpine --format '{{json .Config.Volumes}}'
# {"/var/lib/postgresql/data":{}}

docker inspect "$(docker compose ps -q db)" --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{"\n"}}{{end}}'
# bind   -> /docker-entrypoint-initdb.d
# volume 9a65903da0dae839… -> /var/lib/postgresql/data
```

**The image declares `VOLUME /var/lib/postgresql/data`**, so Docker satisfies it with an
**anonymous volume** — a real volume with a random hex name. The data was never in the writable
layer at all.

And that is exactly why it vanished:

```bash
docker volume ls --format '{{.Name}}' | grep -E '^[0-9a-f]{64}$'   # the orphan is still there
```

| | What happens |
|---|---|
| `docker compose down` | the container goes. The anonymous volume is **left behind**, unnamed |
| `docker compose up` | a **new** container gets a **new** anonymous volume — empty |
| the old rows | still on your disk, in a volume nothing can address by name. Orphaned |

> So the honest sentence is not "containers lose data". It is: **unnamed state is unreachable
> state.** The rows did not get deleted — they got disconnected, and they are now disk you will
> never reclaim on purpose. Step 3 changes one thing: the volume gets a name.

Clean up the orphan while they watch — this is also how laptops end up with 40 GB of these:

```bash
docker volume ls -qf dangling=true | head
docker volume prune -f          # deletes every volume no container references
```

```bash
docker compose down
```
