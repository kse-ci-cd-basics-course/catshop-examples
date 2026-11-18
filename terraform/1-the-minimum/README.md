# 2 · In a pipeline

Same stack. Same four verbs. A machine runs them instead of you.

One file: **`cloud.tf`**. That is the entire step.

## Why that one file is the whole step

A runner is destroyed when the job ends. Keep the state beside the configuration and every
run starts from an empty folder:

- `plan` always says *9 to add*, never *No changes.*
- nothing is ever drift, because there is no previous run to differ from
- the lock exists and never contends — one job, one state, one writer
- `destroy` is mandatory at the end, because nothing can be allowed to leak

That is not a deployment pipeline. It is an integration test that happens to use Terraform.
`cloud.tf` fixes it by moving the state somewhere that outlives the machine.

## What to create, once

Free, no credit card, your own account.

1. Sign in at `app.terraform.io` with GitHub
2. Create an **organization** of your own
3. Create a workspace — choose **CLI-driven workflow**. *Not* "Version control workflow":
   that one runs itself on every commit and fights the pipeline
4. Workspace → Settings → General → **Execution Mode: `Local`**
5. User Settings → Tokens → create an API token
6. Repository → Settings → Secrets → `TF_API_TOKEN`

Then put your organization in `cloud.tf`.

> **Execution Mode must be `Local`.** The default is `Remote`, which runs Terraform on
> HashiCorp's machines — and there is no Docker daemon there, no access to your network, and
> no `/var/run/docker.sock`. The error you get talks about the provider, never about the
> setting. This costs people an evening.

The state service holds the state and the lock. Your runner still does the work.

## The thing to actually look at

Run the workflow **twice** and read the `plan` step both times.

```
run 1   Plan: 9 to add, 0 to change, 0 to destroy.
run 2   No changes. Your infrastructure matches the configuration.
```

The second sentence is impossible with the state on the runner, and it is the whole reason
`cloud.tf` exists. Terraform now remembers, across machines, what it built.

Then open the workspace in the browser: every run, who started it, and what it changed.

## Two applies, one lock

Start the workflow twice in quick succession. The second run waits on the `concurrency`
group; remove that block and it reaches Terraform instead, which tells it the truth:

```
Error: Error acquiring the state lock
Lock Info:
  Operation: OperationTypeApply
```

The lock is why `cancel-in-progress` is `false` here. Cancelling an apply half way through
leaves the state describing a world that no longer exists.

## What is still wrong with this step

It applies straight from a push. Nobody reviewed anything, and the plan was never seen by a
person before it changed the world. That is `../1a-plan-on-pr-apply-on-main`.
