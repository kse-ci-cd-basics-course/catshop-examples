# Deploying it, declared

Five steps. The **stack is byte-identical in all of them** — `md5 */main.tf` proves it — so
every diff between two steps is a diff in the *pipeline*, never in the thing being deployed.

```bash
md5 1-the-minimum/main.tf 2-*/main.tf                  # one hash: the stack never changes
diff 1-the-minimum/ci.yml 2-plan-on-pr-apply-on-main/pull-request.yml
diff 2-plan-on-pr-apply-on-main/pull-request.yml 2a-checks-before-the-plan/pull-request.yml
```

| | Step | The pain | What it adds |
|---|---|---|---|
| 1 | `1-the-minimum` | you can describe the stack, nothing has run it, and a runner has no memory | **the stack, and a pipeline that applies it** — plus `cloud.tf`, so the state outlives the job and the second run can say `No changes.` |
| 2 | `2-plan-on-pr-apply-on-main` | the apply ran on a push nobody read | **plan on the pull request, apply on main** — `-out=tfplan`, the plan as a comment and an artifact, an environment gate, a concurrency group |
| 2a | `2a-checks-before-the-plan` | the plan was correct and the file was still wrong | **the ladder in front of plan** — `fmt`, `validate`, `tflint`, `terraform test` |
| 3 | `3-gcp` | it all deploys to a daemon on your own machine | **the same architecture on a real cloud** — a VPC and its firewall rules, a managed instance group, Cloud SQL on a private address, state in a bucket, and a pipeline that stores no key at all |
| 4 | `4-aws` | one cloud's vocabulary looks like the only way to say it | **the same file on AWS**, read side by side — regional VPCs and zonal subnets, three load-balancer objects instead of five, and the same OIDC trust written as a role |

**`2a` is a branch, not the next step.** It is `2-plan-on-pr-apply-on-main` with three more rungs.

## What the stack is

```
localhost:8080 ──▶ nginx ──┬──▶ app-0 ──┐
                           └──▶ app-1 ──┴──▶ postgres
```

nginx is the load balancer, because a load balancer is a role, not a product — and this one
you can open and read.

- `main.tf` · five resources and the graph between them
- `nginx.conf.tftpl` · rendered by `templatefile()`, so the pool follows `var.replicas`
- `variables.tf` · `docker_host` has **no default**, on purpose
- `outputs.tf` · `url`, the pool, and a password that is `sensitive` in the log and plaintext
  in the state

The application is `../app` — the same `app.py` as every other example here, byte for byte.
It is never told it is one of several: nginx reports which backend answered in
`X-Served-By`. The application did not change to be load balanced; its composition did.

## Before any of the pipelines: one free account, five clicks

No credit card, and one account each — the free plan's user limit per organization is small,
so share an organization and you will run out of seats.

1. `app.terraform.io`, sign in with GitHub
2. Create an **organization**
3. Create a workspace as **CLI-driven workflow** — *not* "Version control workflow"
4. Workspace → Settings → General → **Execution Mode: `Local`**
5. User Settings → Tokens → an API token → repository secret `TF_API_TOKEN`

> **Execution Mode must be `Local`.** The default runs Terraform on HashiCorp's machines,
> which have no Docker daemon and no access to your network. The error blames the provider
> and never mentions the setting.

The state service holds the state and the lock. Your runner still does the work.

## Measured

Apple Silicon macOS, Docker Desktop, Terraform 1.9.8 (run from the `hashicorp/terraform`
image), 18 Nov 2026.

| | |
|---|---|
| first apply, cold — includes building the app image | **28.8s**, 9 resources |
| apply again, image cached | **3s** |
| destroy | **5s**, zero containers, networks or volumes left |
| `plan` after stopping one replica by hand | `Plan: 1 to add, 0 to change, 0 to destroy.` |
| `terraform test` (`2a-checks-before-the-plan`) | 3 passed, 0 failed |

## Two traps the first run teaches, both measured here

**The pool takes about thirty seconds to settle.** `max_fails=1 fail_timeout=5s` excludes a
backend that failed once — including one that was merely slow to start. Measured: every
request went to a single replica for the first ~30s after apply, then settled to 5 and 5 out
of 10. A probe that runs the moment `/health` answers sees one replica and concludes the
load balancer is broken. It is not; it is early.

**A stopped container does not refuse connections — it stops answering.** The first version
of `nginx.conf.tftpl` here had `proxy_next_upstream` and no timeouts, and with one replica
stopped **six of twelve requests failed outright**, because nginx was still waiting on its
default 60-second connect timeout and the failover never got to run. `proxy_connect_timeout
2s` fixes it: 12 of 12, measured. That line is the difference between redundancy you wrote
down and redundancy you have.
