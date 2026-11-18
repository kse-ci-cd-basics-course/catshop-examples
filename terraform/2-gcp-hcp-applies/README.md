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
