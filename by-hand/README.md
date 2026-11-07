# by hand

Six files, one device: **take an action away and write what it was doing.**

An action is a program somebody else maintains. Nothing in it is privileged, nothing
in it is magic, and every one of these five turns out to be a shell script with a
clear job. The point is not to stop using them — it is that after you have seen the
script, the action's *failures* read as ordinary failures instead of as weather.

| File | The action | What the script shows |
|---|---|---|
| `checkout.yml` | `actions/checkout` | `git init` + a token in the remote URL + `fetch --depth=1 <sha>`. Why `git describe` fails, why a PR's `GITHUB_SHA` is on no branch, and what the post-step cleans up |
| `login.yml` | `docker/login-action` | `docker login --password-stdin`, the **base64** in `~/.docker/config.json`, and the short-lived bearer token the registry actually trusts |
| `buildx.yml` | `setup-buildx` + `build-push` | the default builder **cannot export a cache** — that is why setup exists. Then where the layer cache actually lives: `type=gha` entries **listed through the caches API**, and `type=registry` **fetched as a manifest with curl** |
| `registry-push.yml` | `docker push` | an image pushed to GHCR in **five HTTP calls** — token, blob session, blob `PUT`, manifest `PUT`, read back by digest. No `docker push` anywhere in it |
| `cache.yml` | `actions/cache` | the **real service**, in four curls: `CreateCacheEntry` → `PUT` the tarball to the signed URL → `FinalizeCacheEntryUpload` → `GetCacheEntryDownloadURL` in another job. Then the same entry, listed by the REST API |
| `artifact.yml` | `upload`/`download-artifact` | an artifact is a **zip behind an API you already have a token for** — `gh api .../artifacts/<id>/zip` + `unzip`. Same shape as the cache, opposite promise |

## Each pair runs side by side on purpose

Most files have an action job beside the by-hand job — dispatch one and read the two logs
next to each other. `registry-push.yml` has no action half: there is nothing to compare,
because the five calls *are* what `docker push` does.

```bash
gh workflow run by-hand-cache.yml && gh run watch
```

(None of these are in `.github/workflows/`, so none of them run until you copy one
there. Same rule as the `pipeline/` chapters.)

## Where each one is used in the lecture

- `checkout.yml` — §2, the runner. The machine starts empty; the token is the only
  thing it is given.
- `login.yml` — §4, the registry. The login is inside the job because the job is the
  only thing that exists, and a **fork PR gets a read-only token and no secrets**.
- `buildx.yml` — §7, the layer cache. The prerequisite half of chapter 11, and the proof
  that the layer cache is the same store as the dependency cache.
- `registry-push.yml` — §5 and §6. A manifest is a JSON file naming blobs; a tag is a key
  in the registry's table; a digest is the content. The push makes all three concrete.
- `cache.yml` — §7, the cache. The fun-tier slide: *that is the whole action.*
- `artifact.yml` — §7, cache **or** artifact. The rule is in one sentence at the top
  of the file.

## The two honest caveats

Both the cache service (v2) and the artifact service (v4) now speak their own binary
protocols, so the **upload** halves are no longer a one-line `curl`. The shape has not
changed — authenticated HTTP, a key, a tarball, somebody else's disk — and the read
side of both is still plain enough to do by hand, which is what the files show.

Where a credential is printed, it is truncated: `${VAR:0:12}`. Keep it that way. A log
is readable by everyone who can read the repository.
