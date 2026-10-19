# syntax=docker/dockerfile:1

# ═══ STAGE 1 · build ══════════════════════════════════════════════════════════
# `AS build` names the stage. Everything in here is thrown away unless a later
# stage explicitly COPY --from=build it. The compiler lives and dies here.
FROM python:3.12-slim AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential libpq-dev \
 && rm -rf /var/lib/apt/lists/*

# A virtualenv is the easiest artifact to carry across a stage boundary:
# one self-contained directory, no system paths to reconcile.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ═══ STAGE 2 · runtime ════════════════════════════════════════════════════════
# A second FROM starts a brand-new filesystem. Nothing above this line exists
# here — not the compiler, not apt's lists, not pip's cache, not /opt/venv
# until we ask for it on the next line.
FROM python:3.12-slim

RUN useradd --create-home --uid 10001 app \
 && mkdir -p /data && chown app:app /data

# The one thing we carry over. This single line is the whole technique.
COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app
COPY app.py .

USER app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"
CMD ["python", "app.py"]
