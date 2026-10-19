# Step 1 — the anatomy of a Dockerfile

**Files:** `Dockerfile`, `.dockerignore`, `app.py`, `requirements.txt`. No Compose yet.

## The ten parts, in the order they must appear

| # | Instruction | What it decides | Get it wrong and… |
|---|---|---|---|
| 1 | `FROM python:3.12-slim` | the base filesystem | `:latest` → builds stop being reproducible |
| 2 | `RUN useradd … && mkdir` | system setup, in **one** layer | split `apt` layers install against a stale index; a later `rm` frees nothing |
| 3 | `WORKDIR /app` | where relative paths resolve | `COPY . .` lands somewhere surprising |
| 4 | `COPY requirements.txt` + `RUN pip install` | **dependencies, first** | put source first and every edit reinstalls every package |
| 5 | `COPY app.py .` | **source, last** | — |
| 6 | `ENV PORT=8080` | defaults, not secrets | a baked-in secret is in the image forever |
| 7 | `USER app` | drops root | root in a container is root on the shared kernel |
| 8 | `EXPOSE 8080` | documents a port | believing it publishes one. **It does not** |
| 9 | `HEALTHCHECK` | liveness the platform can read | nothing can gate on readiness |
| 10 | `CMD ["python","app.py"]` | the process, in **exec form** | shell form swallows `SIGTERM`; your container takes 10 s to stop |

## Run it

```bash
docker build -t catshop:step1 .
docker run -d --name step1 -p 8080:8080 catshop:step1
curl localhost:8080/health      # ok
curl localhost:8080/visits      # {"store":"file","visits":1}
curl localhost:8080/visits      # {"store":"file","visits":2}
docker ps                       # STATUS … (healthy)
docker run --rm catshop:step1 id   # uid=10001(app) — not root
```

## The run flags, since they are not self-evident

| Flag | What it does | Without it |
|---|---|---|
| `-d` | **detach** — background, prints the container ID | your terminal attaches to Flask's log and `Ctrl-C` stops the container. You could not `curl` it |
| `--name step1` | a stable handle, so later commands can say `step1` | Docker invents `nostalgic_hopper`, different every run, and you copy IDs by hand |
| `-p 8080:8080` | publish **host:container**, in that order | nothing on the host reaches it — `EXPOSE` alone publishes nothing |
| `--rm` | delete the container the moment it exits | throwaway probes pile up as stopped containers |

Two notes that cost people time:

- **A name must be unique, and a stopped container still owns its name.** Re-run the command and you
  get `Conflict. The container name "/step1" is already in use`. Hence the `docker rm -f step1` at the
  end of this file.
- **The name is a hostname.** On a user-defined network, other containers resolve it. That is why
  step 2 can write `@db:5432` and step 5 is where we prove it.

Compose does this for you — containers come out as `<project>-<service>-<index>` (e.g.
`catshop-step3-db-1`), which is why no `--name` appears from step 2 onwards and you address services
instead: `docker compose exec app …`.

## Two things to point at

```bash
docker history catshop:step1 --format '{{.Size}}\t{{.CreatedBy}}' | head
```
Every instruction is a layer, and you can see which one costs.

```bash
docker rm -f step1
docker run -d --name step1 catshop:step1     # no -p this time
curl localhost:8080/health                    # connection refused
```
`EXPOSE 8080` is in the image and the port is still closed.

**What is missing:** the counter lives in `/data/visits.txt` **inside the container**. Destroy the
container and the number resets. Step 2 moves it to a real database — and step 2 loses it anyway.

```bash
docker rm -f step1
```
