# 2 · A real cloud, applied by the state service

Same architecture as `../1-the-minimum`, on Google Cloud. **There is no workflow file in this
folder**, and that absence is the whole point: HCP Terraform is connected to this repository
and runs Terraform itself.

```bash
ls *.yml          # nothing
```

| | `../1-the-minimum` | here |
|---|---|---|
| who runs `apply` | a GitHub runner | **HCP** |
| where the state lives | HCP | HCP |
| what is in the repository | an HCP token | **nothing** |

## What to connect, once

1. HCP Terraform → **Settings → Version Control → Providers** → connect the **GitHub App**
2. New workspace → **Version control workflow** → pick this repository
3. Working directory: `terraform/2-gcp-hcp-applies`
4. Workspace → Settings → **Execution Mode: `Remote`** — the default, and correct here
5. The Google credential, below

Then put your organization in `cloud.tf`.

## Where the Google credential went

It did not disappear, it moved into the workspace. Two ways:

- paste a service-account key into a variable — works, and it is a long-lived key in a form
- **dynamic provider credentials** — HCP federates to Google, the same exchange a runner
  would do, with nothing stored at either end

Use the second. It is the identical idea to `../3-gcp-github-oidc`, with HCP as the issuer
instead of GitHub.

## What you get

Open a pull request that touches this folder and HCP plans it by itself — a check appears on
the pull request with the plan behind it, no YAML involved. Merge, and it applies, with the
run, the diff and whoever approved it in the workspace's history.

## It watches the repository, not your pipeline

This is the part worth getting straight, because the name "VCS integration" makes it sound
like a stage that comes after CI. It is not.

HCP becomes a **second, independent consumer of the same commit**. It sits beside the
pipeline, not after it:

```
            ┌─▶ GitHub Actions   test ─> build ─> publish ─> qa ─> deploy
a merge ────┤
            └─▶ HCP              plan ─> apply
```

So on a merge it applies, and it does not know:

- whether the test suite passed
- whether the image was built, or published, or ever existed
- whether QA ran at all

**It will apply a commit your tests rejected.** `../../.github/workflows/main.yml` deploys
behind `needs: [publish, qa]`; there is no equivalent here without abandoning VCS mode and
driving it from the API instead — at which point you are writing a pipeline again.

That is the real argument against this mode for deploying a *service*. It is a much better
fit for infrastructure that has no test suite in front of it.

## So why have it at all

Strip the product page and the free tier gives you exactly one thing you cannot trivially do
yourself: **managed state with a lock, without owning a bucket.**

Everything else duplicates something you already have:

| | here | what you already use |
|---|---|---|
| state and the lock | the workspace | a GCS or S3 bucket, a few cents a month |
| who applied what, and when | the workspace's run history | the Actions run log and its summary |
| approval before apply | the workspace | `environment:` with a required reviewer |
| variables and secrets | the workspace | repository variables and secrets |
| policy enforcement | Sentinel / OPA — **paid** | — |
| scheduled drift detection | **paid** | a scheduled workflow you write |

Which decides where it earns its place:

- **`../1-the-minimum`** — load-bearing. There is no cloud account there, so there is **no
  bucket to put state in**. Without it the state dies with the runner and `No changes.`
  becomes a sentence that can never be true.
- **here and `../3-gcp-github-oidc`** — a preference. You already have a project, so a state
  bucket is three `gcloud` commands.

**Managed state is how you get a backend when you have nowhere to put one.** Once you have a
cloud account, a bucket does the same job and your pipeline already does the rest.

## The two things that bite

**Remote execution has no Docker daemon.** It is why `../1-the-minimum` cannot be run this
way and has to stay CLI-driven with Execution Mode `Local`. Remote runners are HashiCorp's
machines: they have no access to your socket, your network or anything private.

**One driver per workspace.** If HCP applies this workspace, nothing in GitHub Actions may
apply it too. Two writers against one state race for the same lock on the same commit, and
the one that loses fails in a way that looks like a bug in Terraform.

## What it costs you to read

Nothing is applied by looking at this folder. Applying it costs what `../3-gcp-github-oidc`
costs — the same resources, priced in that README.
