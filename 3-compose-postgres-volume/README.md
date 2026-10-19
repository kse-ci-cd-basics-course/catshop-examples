# Step 3 — add a volume, keep the data

```bash
diff -u ../2-compose-postgres-no-volume/compose.yaml compose.yaml
```

That diff is the whole step: one mount under `db`, and one `volumes:` key at the bottom.

## Run the identical experiment

```bash
cp .env.example .env
docker compose up -d --build
curl localhost:8080/visits        # visits=1
curl localhost:8080/visits        # visits=2
docker compose down
docker compose up -d
curl localhost:8080/visits        # visits=3   <-- it survived
```

**The container was destroyed and recreated. The data stayed.**
Write down the sentence: *the container is disposable, the data is not.*

## Where it lives now

```bash
docker volume ls --filter name=pgdata
docker volume inspect catshop-step3_pgdata --format '{{.Mountpoint}}'
docker run --rm -v catshop-step3_pgdata:/d alpine ls /d | head -5
```

The volume is named `<project>_pgdata`. The project defaults to the directory name, which makes
volume names move when a folder is renamed — so `compose.yaml` here pins it with a top-level
`name: catshop-step3`. Check what yours resolved to:

```bash
docker compose config --format json | python3 -c 'import json,sys;print(json.load(sys.stdin)["name"])'
```

## The same `docker diff`, now with a name to point at

```bash
docker diff "$(docker compose ps -q db)"      # still four paths. Still nothing under /data
docker inspect "$(docker compose ps -q db)" --format '{{range .Mounts}}{{.Type}} {{.Name}}{{"\n"}}{{end}}'
# volume catshop-step3_pgdata        <-- a NAME, not a hex string
```

Step 2 had exactly the same `docker diff` output and exactly the same kind of mount. **The only
difference between losing the data and keeping it is that the volume has a name**, so the next
container can ask for it again.

That is worth stating plainly, because it is the part that surprises people: a volume was always
there. `volumes: pgdata:/var/lib/postgresql/data` did not *add* persistence — it made an existing,
anonymous volume **addressable**.

## The four kinds of mount

| Kind | Syntax | Lives | Survives `down` | For |
|---|---|---|---|---|
| **named volume** | `pgdata:/var/lib/postgresql/data` | Docker's own area | ✅ (not `down -v`) | databases, anything stateful |
| **bind mount** | `./init-db:/docker-entrypoint-initdb.d` | a path in your repo | ✅ (it is your folder) | config, dev source |
| anonymous | `/var/lib/postgresql/data` | Docker's area, unnamed | ✅ then orphaned forever | nothing — this is an accident |
| tmpfs | `tmpfs: [/tmp]` | RAM | ❌ by design | scratch, secret material |

Both kinds are already in this file: `pgdata` is named, `./init-db` is a bind mount. Point at them.

## Two more things, then move on

```bash
docker compose exec -T db pg_dump -U shop -Fc shop > shop.dump   # consistent while running
docker compose exec db sh -c 'echo $PGDATA'                      # verify, never assume
```

> **Warning — destructive.** `docker compose down -v` deletes the volume and every row in it, with
> no confirmation and no undo. It is the right command after editing a seed script, and the wrong
> habit to type by reflex.

```bash
docker compose down
```
