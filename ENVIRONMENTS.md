# The three environments

`14-environments.yml` reads everything from the environment a job claims, so the deploy steps
are identical for all three. **Settings → Environments → New environment**: `sandbox`, `stage`,
`production`.

These are **environment** variables, not repository ones. The same name exists three times with
three values, and `vars.APP_HOST` resolves to whichever environment the job claimed. A
repository variable would be one value for all three, which is the thing we are avoiding.

Lookup order is **environment → repository → organisation**, nearest wins. A job with no
`environment:` key sees only the repository and organisation ones.

## Variables

| Name | sandbox | stage | production |
|---|---|---|---|
| `APP_HOST` | `https://sandbox.catshop.local` | `https://stage.catshop.local` | `https://catshop.example` |
| `REPLICAS` | `1` | `2` | `6` |
| `LOG_LEVEL` | `debug` | `info` | `warn` |
| `FEATURE_NEW_CHECKOUT` | `on` | `on` | `off` |
| `VAULT_ROLE` | `catshop-sandbox` | `catshop-stage` | `catshop-prod` |
| `DRY_RUN` | `true` until something is really deployed there | `true` | `true` |

**`DRY_RUN`** is the one that is not permanent. While no host exists, the qa action prints the
pack it would have run instead of curling a URL that is not there. Set it to `false` per
environment as each one becomes real.

A missing variable is an **empty string, not an error** — so `vars.APP_HOST` unset would turn
`curl "$HOST/health"` into `curl "/health"` and fail for a reason that reads like a bug. The qa
action checks for it and says so instead.

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

## What a pull request may reach

`sandbox` and `stage`. **Not production** — that job carries
`if: github.ref == 'refs/heads/main'`, so there is no label, no approval and no mistake that
lets a pull request deploy it.

Set **deployment branches** on each environment too, so the rule is enforced by GitHub and not
only by the file: `sandbox` and `stage` allow any branch, `production` allows `main` only.
