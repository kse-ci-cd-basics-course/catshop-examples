# Step 4 — WireMock: the API you do not own

```bash
diff -u ../3-compose-postgres-volume/compose.yaml compose.yaml
```

**New:** a `partner` service and two environment variables. `partner/mappings/*.json` is the
third party's behaviour, written down.

## Why a stub exists at all

| | our database | the partner's API |
|---|---|---|
| Who runs it | us | somebody else |
| Can we restart it | yes | no |
| Can we make it return a 500 on demand | yes | **no** |
| Can we make it slow on demand | yes | **no** |
| Should our test suite call it | yes, a real container | **never** |

> **Our own dependencies get a real container. Somebody else's API gets a stub.**
> A database you own is cheap to run and expensive to fake. An API you do not own is the reverse.

## Run it

```bash
cp .env.example .env
docker compose up -d --build
curl localhost:8080/price/MK-II
# {"currency":"UAH","price":"1234.56","sku":"MK-II","source":"http://partner:8080/v1/catalog/MK-II"}
```

The price came from another container, reached by the hostname `partner`.

## Now the three things the real partner would never do for you

```bash
curl localhost:8080/price/BOOM-1     # 502 — the stub returns 500 (catalog-broken.json)
curl localhost:8080/price/SLOW-1     # 502 after 2 s — the stub delays 5 s, our timeout is 2 (catalog-slow.json)
curl localhost:8080/price/MK-II      # still fine
```

Three failure modes, on demand, from three small JSON files:

```bash
cat partner/mappings/catalog-broken.json
cat partner/mappings/catalog-slow.json
```

## The stub also records

```bash
curl -s -X POST localhost:8080/../__admin/requests/count 2>/dev/null || true
docker compose exec -T partner sh -c \
  'wget -qO- --post-data="{\"method\":\"GET\",\"urlPathPattern\":\"/v1/catalog/.*\"}" \
   --header="Content-Type: application/json" http://localhost:8080/__admin/requests/count'
```

*"The app called the partner exactly once"* is an assertion you cannot make by patching a Python
function — at the HTTP level it is free. the WireMock test in your own lab repo does exactly this.

**What is still wrong:** `docker compose ps` shows the database is not published — but nothing stops
the database, or the partner stub, from opening connections **out** to the internet. Step 5 closes
that door.

```bash
docker compose down
```
