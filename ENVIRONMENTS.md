# The three environments

`14-environments.yml` reads everything from the environment a job claims, so the deploy steps
are identical for all three. **Settings → Environments → New environment**: `sandbox`, `stage`,
`production`.

## Variables

| Name | sandbox | stage | production |
|---|---|---|---|
| `APP_HOST` | `https://sandbox.catshop.local` | `https://stage.catshop.local` | `https://catshop.example` |
| `REPLICAS` | `1` | `2` | `6` |
| `LOG_LEVEL` | `debug` | `info` | `warn` |
| `FEATURE_NEW_CHECKOUT` | `on` | `on` | `off` |
| `VAULT_ROLE` | `catshop-sandbox` | `catshop-stage` | `catshop-prod` |

## Secrets

`DEPLOY_TOKEN` in each — a credential for the platform being deployed to, scoped to that one
environment and revocable on its own.

## Protection rules

On **production** only: required reviewers, and deployment branches **selected → `main`**. The
gate is a property of the environment, which is why no job in the file has an `if:` for it — the
run reaches `deploy-prod` and waits.

## What is deliberately not here

No `DATABASE_URL`, no payment key, no signing key. Those live in a secret manager, and the
**running app** fetches them at startup with an identity the platform gives it. The pipeline
passes only the address — `VAULT_ROLE`.

> A pipeline secret is a credential for **deploying**. An application secret is a credential for
> **running**, and the pipeline should never see it.

## The opt-in sandbox deploy

On a pull request, `deploy-sandbox` runs only if the PR carries the label **`deploy:sandbox`**.
Create the label once. Adding it re-triggers the workflow, which is what `types: [labeled]` is
for.
