-- Runs ONLY when the data directory is empty. Edit it on an existing volume and nothing
-- happens: `docker compose down -v && docker compose up -d` is the (destructive) reset.
CREATE TABLE IF NOT EXISTS visits (
  id serial PRIMARY KEY,
  at timestamptz DEFAULT now()
);
