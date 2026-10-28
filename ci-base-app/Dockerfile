# Basic Dockerfile
FROM python:3.12-slim

RUN useradd --create-home --uid 10001 app \
 && mkdir -p /data && chown app:app /data

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

ENV PORT=8080 PYTHONUNBUFFERED=1
USER app

EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"
CMD ["python", "app.py"]
