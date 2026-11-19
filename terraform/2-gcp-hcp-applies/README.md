# 2 · Applied by the state service

One bucket, one label, and **no workflow file in this folder**. HCP Terraform is connected to
this repository, so it plans every pull request and applies on merge by itself.

```bash
ls *.yml          # nothing
grep -r backend . # nothing
```

Both absences are the lesson. The architecture is not the point here —
`../3-gcp-github-oidc` has the load balancer, the two instances and the database. This folder
answers a different question: **who runs Terraform, and how does the code know?**

It does not know. That is the answer.

## Try it

Edit one line:

```hcl
labels = {
  message = var.message
}
```

Change `message`'s default in `variables.tf`, push to `main`, and a run starts without you.
Watch it in the workspace, then:

```bash
terraform output message
```

An empty bucket costs approximately nothing, so it can stay up.

## Why there is no backend block

Where the state lives and who runs `apply` are **not properties of this configuration**.

The workspace already knows the repository, the branch, this directory and its own state, so
nothing in the code has to name any of it. Putting a `cloud` block here would hardcode an
organization into a file that every fork would then have to edit.

`terraform init` on your own machine in this folder gives you a **local** state file, because
that is what a configuration with no backend means. To reach the same workspace from a
terminal, say so in the environment instead of in the code:

```bash
export TF_CLOUD_ORGANIZATION=your-org
export TF_WORKSPACE=catshop-gcp
terraform init
```

Compare `../3-gcp-github-oidc/backend.tf`, which *has* to name a bucket, because there the
CLI is the thing doing the work.

## What to connect, once

1. HCP Terraform → **Settings → Version Control → Providers** → connect the **GitHub App**
2. New workspace → **Version control workflow** → this repository
3. Working directory: `terraform/2-gcp-hcp-applies`
4. Execution Mode **`Remote`** — the default, and correct here
5. Auto-apply on, if you want merges to apply without a second click
6. Workspace variables: `project_id`, and the Google credential below

## Where the Google credential went

It did not disappear, it moved into the workspace. Either a service-account key pasted into a
variable, or **dynamic provider credentials**, where HCP federates to Google — the same
exchange a runner would do, with nothing stored at either end. Use the second.

## It watches the repository, not your pipeline

"VCS integration" sounds like a stage after CI. It is not. HCP becomes a **second,
independent consumer of the same commit**:

```
            ┌─▶ GitHub Actions   test ─> build ─> publish ─> qa ─> deploy
a merge ────┤
            └─▶ HCP              plan ─> apply
```

So on a merge it applies, and it does not know whether the suite passed, whether the image
was built, or whether QA ran.

**It will apply a commit your tests rejected.**

`../../.github/workflows/main.yml` deploys behind `needs: [publish, qa]`. There is no
equivalent here without abandoning VCS mode and driving it from the API — at which point you
are writing a pipeline again.

That is the real argument against this mode for a **service**. For infrastructure with no
test suite in front of it — a bucket, a DNS zone, IAM — it is a good fit, which is exactly
what this folder contains.

## So why have it at all

The free tier gives you one thing you cannot trivially do yourself: **managed state with a
lock, without owning a bucket.** Everything else duplicates something you already have:

| | here | what you already use |
|---|---|---|
| state and the lock | the workspace | a GCS or S3 bucket, a few cents a month |
| who applied what, and when | the workspace's run history | the Actions run log and its summary |
| approval before apply | the workspace | `environment:` with a required reviewer |
| variables and secrets | the workspace | repository variables and secrets |
| policy enforcement | Sentinel / OPA — **paid** | — |
| scheduled drift detection | **paid** | a scheduled workflow you write |

Which decides where it earns its place:

- **`../1-the-minimum`** — load-bearing. No cloud account means **no bucket to put state in**,
  so without it the state dies with the runner and `No changes.` can never be true.
- **here and `../3-gcp-github-oidc`** — a preference. You have a project, so a state bucket is
  three `gcloud` commands.

**Managed state is how you get a backend when you have nowhere to put one.** Once you have a
cloud account, a bucket does the same job and your pipeline already does the rest.

## The one that bites

**Remote execution has no Docker daemon.** It is why `../1-the-minimum` cannot run this way
and stays CLI-driven with Execution Mode `Local`. Remote runners are HashiCorp's machines:
no access to your socket, your network, or anything private.
