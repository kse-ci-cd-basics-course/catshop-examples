# Step 5 — networks, and the door that closes

```bash
diff -u ../4-compose-wiremock-partner/compose.yaml compose.yaml
```

**New:** a `networks:` key on each service and a `networks:` block at the bottom. **No service was
added or removed.** Everything in steps 2–4 already worked — this step makes explicit what Compose
was doing implicitly, and then takes privileges away.

## First: why the name `db` ever worked

Steps 2–4 wrote `@db:5432` and nobody asked why that resolves. Take Compose out of it:

```bash
docker run -d --name solo -e POSTGRES_PASSWORD=pw -e POSTGRES_USER=shop -e POSTGRES_DB=shop postgres:16-alpine

# 1 — localhost: that is THIS container, not the other one
docker run --rm catshop:step5 python -c \
  "import socket;socket.create_connection(('localhost',5432),3)"

# 2 — by name on the DEFAULT bridge: no DNS exists there at all
docker run --rm catshop:step5 python -c \
  "import socket;socket.create_connection(('solo',5432),3)"

# 3 — by IP: works, and is already wrong
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' solo
docker restart solo
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' solo   # a different IP

# 4 — by name on a network you created: works, and keeps working
docker network create demo && docker network connect demo solo
docker run --rm --network demo catshop:step5 python -c \
  "import socket;socket.create_connection(('solo',5432),3);print('reachable by name')"

docker rm -f solo && docker network rm demo
```

Attempts 1 and 2 fail, 3 works and goes stale on the next restart, 4 is the one you keep.
**A user-defined network is a free DNS server, and the service name is the hostname.**

## Then: who can reach whom

```bash
cp .env.example .env
docker compose up -d --build
curl localhost:8080/visits        # app -> db     works
curl localhost:8080/price/MK-II   # app -> partner works
```

```bash
docker compose ps                 # the db and the partner publish NOTHING
for s in app db partner; do printf '%-8s %s\n' "$s" \
  "$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$(docker compose ps -q $s)")"; done
```

| Service | Networks | Consequence |
|---|---|---|
| `app` | frontend, backend, partnernet | the only path. Reaches both, published on loopback |
| `db` | backend *(internal)* | reachable only by `app`. No route to the internet |
| `partner` | partnernet *(internal)* | same. A stub cannot phone home |

## The four proofs — run them in this order

```bash
# 1. the database is NOT reachable from your laptop
bash -c 'exec 3<>/dev/tcp/127.0.0.1/5432' || echo "refused, as designed"

# 2. but the app reaches it by name
docker compose exec -T app python -c "import socket;socket.create_connection(('db',5432),3);print('ok')"

# 3. the database cannot reach the internet
docker compose exec -T db ping -c1 -W2 1.1.1.1 || echo "no route, as designed"

# 4. neither can the partner stub
docker compose exec -T partner sh -c 'timeout 3 wget -qO- https://example.com' || echo "no route, as designed"
```

> **Security, stated plainly.** On Linux, publishing a port with `ports:` makes Docker write its own
> `iptables` rules in the `DOCKER` chain, and those are consulted **before** your `ufw` rules — so
> `ufw deny 5432` does **not** block a published container port. The fix is not a firewall rule; it is
> not publishing the port. That is why `db` has no `ports:` entry and `app` binds `127.0.0.1` only.

## The one command that debugs all of this

```bash
docker compose exec -T app cat /etc/resolv.conf        # nameserver 127.0.0.11 = you have DNS
docker run --rm --network catshop-step5_partnernet nicolaka/netshoot sh -c 'nslookup partner; nc -zv partner 8080'
```

`netshoot` on the suspect network answers nearly every "it cannot reach the other service", and it
moves the student from guessing to measuring.

## Where this goes next

Inbound publishing and outbound egress are **different doors**. We opened one (loopback:8080) and
closed the other (`internal: true`). Testcontainers does the same thing at the test level: WireMock
replaces the partner, so the suite cannot call production even by accident.

```bash
docker compose down
```
