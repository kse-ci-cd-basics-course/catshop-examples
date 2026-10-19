#!/usr/bin/env bash
#
# Step 1a — the build cache, measured. Run from this directory:
#
#     ./cache.sh
#
# Every act prints the build time, how many cacheable steps were CACHED, and
# which steps had to be rebuilt. Nothing in README.md is asserted: the numbers
# there are this script's output on a real daemon.

set -uo pipefail
cd "$(dirname "$0")"

GOOD=catshop:cache-good        # ./Dockerfile              — dependencies first
BAD=catshop:cache-bad          # ./Dockerfile.source-first — source first

say()    { printf '\n\033[1;35m=== %s\033[0m\n' "$*"; }
note()   { printf '\033[0;36m    %s\033[0m\n' "$*"; }
moment() { printf '\033[1;33m    >> %s\033[0m\n' "$*"; }

MARKER='# touched by cache.sh'

# This script edits app.py, requirements.txt and .dockerignore on purpose, and
# an interrupted run must not leave them edited.
#
# The restore deletes the marker lines rather than copying back a snapshot taken
# at startup. A snapshot is the obvious design and it is wrong: interrupt the
# script once and the next run snapshots the ALREADY-EDITED file as its
# baseline, so the edits accumulate one line per run, silently. Deleting by
# pattern is idempotent — it repairs a file that a previous run left dirty.
#
# This matters here beyond tidiness: app.py and .dockerignore are byte-identical
# in every step of this repo (`md5 */app.py` is part of the lesson), so a stray
# line would break a documented invariant.
strip_edits() {
  local f="$1" pattern="$2" tmp
  tmp=$(mktemp)
  grep -v "$pattern" "$f" > "$tmp" && mv "$tmp" "$f" || rm -f "$tmp"
}

cleanup() {
  rm -f gotcha.txt
  strip_edits app.py "^${MARKER}"
  strip_edits .dockerignore '^gotcha\.txt$'
  chmod 644 app.py requirements.txt
}
trap cleanup EXIT INT TERM

# Reads a --progress=plain log and reports the cache status of each build step.
#
# Three BuildKit details that would otherwise mislead the reader:
#   * step labels come out as either "[2/6]" or "[stage-0 2/6]", depending on
#     which frontend capabilities the Dockerfile triggers — accept both;
#   * the FROM step reports DONE, not CACHED, once the base image is local, so
#     it is left out of the count entirely;
#   * WORKDIR is metadata-only and is cached unconditionally, so even a build
#     that reran everything shows one hit. The signal is COPY and RUN.
summarize() {
  awk '
    /^#[0-9]+ \[([^]]+ )?[0-9]+\/[0-9]+\] / {
      n = substr($1, 2)
      desc = $0; sub(/^#[0-9]+ \[([^]]+ )?[0-9]+\/[0-9]+\] /, "", desc)
      if (desc ~ /^FROM/) next
      order[++k] = n; step[n] = desc
    }
    /^#[0-9]+ CACHED/ { hit[substr($1, 2)] = 1 }
    END {
      c = 0; shown = 0; missed = ""
      for (i = 1; i <= k; i++) {
        n = order[i]
        if (n in hit) { c++; continue }
        if (++shown > 3) { missed = missed ", …"; break }
        d = step[n]; if (length(d) > 34) d = substr(d, 1, 33) "…"
        missed = missed (missed == "" ? "" : ", ") d
      }
      print c "/" k "|" missed
    }' "$1"
}

# build <label> <dockerfile> <tag> [extra buildx args...]
build() {
  local label="$1" dockerfile="$2" tag="$3"; shift 3
  local log; log=$(mktemp)
  local start; start=$(date +%s)
  docker buildx build --progress=plain "$@" -f "$dockerfile" -t "$tag" --load . >"$log" 2>&1
  local rc=$? end; end=$(date +%s)

  if [ "$rc" -ne 0 ]; then
    printf '    %-32s BUILD FAILED (rc=%s)\n' "$label" "$rc"; tail -5 "$log"; rm -f "$log"; return 1
  fi
  local s; s=$(summarize "$log")
  printf '    %-32s %4ss   CACHED %s\n' "$label" "$((end - start))" "${s%%|*}"
  local missed="${s#*|}"
  [ -n "$missed" ] && printf '    %-32s        rebuilt: %s\n' "" "$missed"
  rm -f "$log"
}

layer_size() {   # the size of the pip install layer in a built image
  docker history "$1" --format '{{.Size}}\t{{.CreatedBy}}' | grep -m1 'pip install' | cut -f1
}

command -v docker >/dev/null || { echo "docker not found"; exit 1; }
docker pull -q python:3.12-slim >/dev/null 2>&1    # so timings measure building, not pulling
cleanup

say "ACT 0 · an image is layers, one per instruction"
build "cold (--no-cache)" Dockerfile "$GOOD" --no-cache
docker history "$GOOD" --format '{{.Size}}\t{{.CreatedBy}}' | head -8
note "Each line is a filesystem diff. The cache is kept per line, not per image."

say "ACT 1 · rebuild with nothing changed"
build "unchanged" Dockerfile "$GOOD"
note "Same inputs, same keys, no work. This is 'seconds instead of minutes'."

say "ACT 2 · touch app.py — make them predict before you run it"
touch app.py
build "after touch" Dockerfile "$GOOD"
moment "Still cached. Modification time is NOT in the cache key."
note "The key covers file contents, permissions and path. Not mtime."

say "ACT 3 · actually change app.py — what a developer does fifty times a day"
printf '%s %s\n' "$MARKER" "$(date +%T)" >> app.py
build "dependencies first" Dockerfile "$GOOD"
build "source first" Dockerfile.source-first "$BAD"
moment "Same edit, same resulting app. One of them reinstalled every dependency."
note "Dependencies-first kept the pip layer: requirements.txt did not change."
note "Source-first put 'COPY . .' ABOVE the install, so the install is downstream"
note "of every file in the project, app.py included."
strip_edits app.py "^${MARKER}"

say "ACT 4 · create one unrelated file. HA, GOT YA"
build "source first, baseline" Dockerfile.source-first "$BAD"
build "dependencies first, baseline" Dockerfile "$GOOD"
echo "ha, got ya" > gotcha.txt
build "source first, + gotcha.txt" Dockerfile.source-first "$BAD"
build "dependencies first, + gotcha.txt" Dockerfile "$GOOD"
moment "gotcha.txt is not imported, not read, not used by the app at all."
note "But it IS in the build context, so the key of 'COPY . .' changed, and the"
note "pip install sits below that node. A miss invalidates everything downstream."
note "Dependencies-first never saw the file: it copies two files, by name."

say "ACT 5 · the fix — take the file out of the build context"
echo 'gotcha.txt' >> .dockerignore
build "source first, now ignored" Dockerfile.source-first "$BAD"
echo "ha, got ya again" >> gotcha.txt
build "source first, file changed again" Dockerfile.source-first "$BAD"
moment "Cached. Outside the context, COPY cannot see it, so it cannot enter a key."
note ".dockerignore is a build-performance file, not only a hygiene file."
strip_edits .dockerignore '^gotcha\.txt$' 

say "ACT 6 · chmod requirements.txt — contents stay byte-identical"
# A mode picked from a pool rather than a fixed 600, because BuildKit keeps every
# variant it has ever built: the second run of this script would otherwise find
# the mode-600 layer already cached and the act would quietly stop biting.
MODES=(600 640 604 660 620 602 664 606)
MODE=${MODES[$((RANDOM % ${#MODES[@]}))]}
chmod "$MODE" requirements.txt
build "after chmod $MODE" Dockerfile "$GOOD"
moment "The COPY missed, so the install below it reran. Permissions ARE in the key."
note "Compare with ACT 2: content untouched in both. mtime is free, mode is not."
note "Flip the mode BACK to one you have built before and it hits the cache again:"
note "keys are content-addressed, so every variant stays, not just the last one."
chmod 644 requirements.txt

say "ACT 7 · what the cache mount actually buys — size, not time"
build "pip cache left in the layer" Dockerfile.pip-in-layer catshop:pip-in-layer --no-cache
build "pip cache on the builder" Dockerfile "$GOOD" --no-cache
printf '    %-32s %s\n' "pip layer, cache in image:"   "$(layer_size catshop:pip-in-layer)"
printf '    %-32s %s\n' "pip layer, cache on builder:" "$(layer_size "$GOOD")"
docker buildx du --filter type=exec.cachemount 2>/dev/null | tail -2
moment "The difference between those two layers is the wheel cache, to the byte."
note "The mount gives you the small layer of --no-cache-dir AND keeps the cache."
note "On this project that is ~8 MB and under a second. Measure before you believe"
note "it matters: on a torch/numpy image the same line is worth minutes."

say "ACT 8 · a cleanup in a later layer frees nothing"
docker buildx build -q -f Dockerfile.split-apt -t catshop:split-apt --load . >/dev/null 2>&1
docker buildx build -q -f Dockerfile.one-layer -t catshop:one-layer --load . >/dev/null 2>&1
docker images --format '{{.Size}}\t{{.Repository}}:{{.Tag}}' | grep -E 'catshop:(split-apt|one-layer)'
moment "Same packages, same rm, different images. A layer can only ADD a diff."

say "CLEANUP"
cleanup
if [ -d ../1-dockerfile ]; then
  if [ "$(md5 -q app.py 2>/dev/null)" = "$(md5 -q ../1-dockerfile/app.py 2>/dev/null)" ]; then
    note "app.py is byte-identical to the other steps again. Invariant holds."
  else
    printf '    \033[1;31m!! app.py drifted from ../1-dockerfile/app.py — restore it before committing\033[0m\n'
  fi
fi
note "Working tree restored. Images kept on purpose, so you can poke at them:"
note "  docker rmi $GOOD $BAD catshop:pip-in-layer catshop:split-apt catshop:one-layer"
