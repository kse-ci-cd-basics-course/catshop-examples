# Deploying it, declared

Three ways to put the same stack somewhere, and they differ along exactly two axes: **who
runs Terraform**, and **who keeps the state**.

| | | runs `apply` | keeps the state | credential to the cloud | stored in the repo |
|---|---|---|---|---|---|
| **1** | `1-the-minimum` | a GitHub runner | HCP | none — it is the Docker socket | **an HCP token** |
| **2** | `2-gcp-hcp-applies` | **HCP** | HCP | HCP → Google | **nothing** |
| **3** | `3-gcp-github-oidc` | a GitHub runner | **a GCS bucket** | OIDC → Workload Identity | **nothing** |

Model 1 is a mock environment on purpose: the provider is `kreuzwerker/docker`, so the
endpoint is a daemon rather than a datacentre and nothing is billed. Everything about plan,
state, the lock and destroy behaves exactly as it does in 2 and 3.

Two variations sit under model 1, because its pipeline is where the pipeline ideas live:

| | | |
|---|---|---|
| `1a-plan-on-pr-apply-on-main` | the apply ran on a push nobody read | `-out=tfplan`, the plan posted as a comment, applied from those bytes behind an environment gate |
| `1b-checks-before-the-plan` | the plan was correct and the file was still wrong | a branch off `1a` — `fmt`, `validate`, `tflint`, `terraform test` |

## The stack never changes

```bash
md5 1-the-minimum/main.tf 1a-*/main.tf 1b-*/main.tf        # one hash
md5 2-gcp-hcp-applies/network.tf 3-gcp-github-oidc/network.tf   # one hash
```

Models 2 and 3 are the same Google configuration byte for byte. The only difference is one
file — `cloud.tf` against `backend.tf` — plus whether there is a workflow beside it.

```
localhost:8080 ──▶ nginx ──┬──▶ app-0 ──┐          model 1
                           └──▶ app-1 ──┴──▶ postgres

a global IP ──▶ load balancer ──┬──▶ instance ──┐  models 2 and 3
                                └──▶ instance ──┴──▶ Cloud SQL
```

The application is `../app` — the same `app.py` as every other example here, byte for byte.
It is never told it is one of several: nginx reports which backend answered in
`X-Served-By`. The application did not change to be load balanced; its composition did.

## Before model 1 or 3: one free account, five clicks

No credit card, one account each — the free plan's user limit per organization is small, so
share an organization and you will run out of seats.

1. `app.terraform.io`, sign in with GitHub
2. Create an **organization**
3. Create a workspace as **CLI-driven workflow**
4. Workspace → Settings → General → **Execution Mode: `Local`**
5. User Settings → Tokens → an API token → repository secret `TF_API_TOKEN`

> **Execution Mode must be `Local` for model 1.** The default runs Terraform on HashiCorp's
> machines, which have no Docker daemon and no access to your network. The error blames the
> provider and never mentions the setting.

Model 2 is the opposite: **Version control workflow**, Execution Mode `Remote`, and no token
in the repository at all.

## Measured

Apple Silicon macOS, Docker Desktop, Terraform 1.9.8 (from the `hashicorp/terraform` image),
18 Nov 2026 — model 1.

| | |
|---|---|
| first apply, cold — includes building the app image | **28.8s**, 9 resources |
| apply again, image cached | **3s** |
| destroy | **5s**, zero containers, networks or volumes left |
| `plan` after stopping one replica by hand | `Plan: 1 to add, 0 to change, 0 to destroy.` |
| `terraform test` (`1b-checks-before-the-plan`) | 3 passed, 0 failed |

## Two traps model 1 teaches, both measured here

**The pool takes about thirty seconds to settle.** `max_fails=1 fail_timeout=5s` excludes a
backend that failed once — including one that was merely slow to start. Measured: every
request went to a single replica for the first ~30s after apply, then settled to 5 and 5 out
of 10. A probe that runs the moment `/health` answers sees one replica and concludes the
load balancer is broken. It is not; it is early.

**A stopped container does not refuse connections — it stops answering.** The first version
of `nginx.conf.tftpl` here had `proxy_next_upstream` and no timeouts, and with one replica
stopped **six of twelve requests failed outright**, because nginx was waiting on its default
60-second connect timeout and the failover never got to run. `proxy_connect_timeout 2s`
fixes it: 12 of 12, measured. That line is the difference between redundancy you wrote down
and redundancy you have.
