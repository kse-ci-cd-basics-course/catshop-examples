# ─── 1. BASE ──────────────────────────────────────────────────────────────────
# Every image starts from another image. The tag is pinned: `latest` means
# "whatever was newest when I happened to build", which is not reproducible.
FROM python:3.12-slim

# ─── 2. SYSTEM SETUP ──────────────────────────────────────────────────────────
# One RUN, because a cleanup only shrinks the image inside the layer that made
# the mess, and `apt-get update` in its own layer goes stale.
# A real user with a fixed UID, so volume ownership is predictable.
RUN useradd --create-home --uid 10001 app \
 && mkdir -p /data && chown app:app /data

# ─── 3. WHERE WE WORK ─────────────────────────────────────────────────────────
# Every relative path after this is relative to /app. Also created if missing.
WORKDIR /app

# ─── 4. DEPENDENCIES — the slow, rarely-changing step goes FIRST ──────────────
# Copying only requirements.txt means editing app.py does not invalidate the
# pip install layer below. This ordering is the whole of build performance.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ─── 5. SOURCE — the fast, constantly-changing step goes LAST ─────────────────
COPY app.py .

# ─── 6. CONFIGURATION ─────────────────────────────────────────────────────────
# Defaults live in the image; real values are injected at run time.
# Nothing secret is ever baked in here.
ENV PORT=8080 \
    PYTHONUNBUFFERED=1

# ─── 7. DROP ROOT ─────────────────────────────────────────────────────────────
# Everything below this line runs as uid 10001. Note the consequence: a
# non-root process cannot bind a port below 1024, which is why we use 8080.
USER app

# ─── 8. DOCUMENTATION, NOT A FIREWALL HOLE ────────────────────────────────────
# EXPOSE publishes nothing. It records intent for humans and for `docker run -P`.
# Only `-p` / `ports:` opens a port on the host.
EXPOSE 8080

# ─── 9. IS IT ACTUALLY ALIVE? ─────────────────────────────────────────────────
# `docker ps` shows (healthy); Compose can gate dependent services on it.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"

# ─── 10. WHAT RUNS ────────────────────────────────────────────────────────────
# Exec form (a JSON array), so the process is PID 1 and receives signals
# directly. The shell form would wrap it in /bin/sh -c and swallow SIGTERM.
CMD ["python", "app.py"]
