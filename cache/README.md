# Four ways something moves, and one rule for choosing

Same two jobs in every file — `produce` and `consume` — with one mechanism swapped.
Run them in order and the limits announce themselves.

| | File | What crosses | Promise |
|---|---|---|---|
| 01 | `01-file-same-job.yml` | nothing leaves the job | a file is free **inside** one job, and invisible outside it |
| 02 | `02-artifact-between-jobs.yml` | **files** | it will be there, or the job fails |
| 03 | `03-output-string.yml` | **one string** | it will be there, and it is a string even when it says `false` |
| 04 | `04-cache-keyed.yml` | **files** | maybe. It is keyed, and it is allowed to be empty |

## The rule

> **If a missing file should FAIL the job, it is an artifact.
> If a missing file should only make the job SLOWER, it is a cache.**

That is the whole decision, and it is why the image a build job hands to a test job is
an artifact — a test that silently runs against nothing is worse than a slow one.

## The thing people get wrong

A cache **does** cross a job boundary, and it **does** cross runs, with nothing
third-party involved. The mistake is not "caches cannot cross" — it is trusting one to.
`pipeline/../s8-16` in the lecture is the real version of this: an image passed to the
deploy job through a cache, green on Tuesday, evicted by Thursday, and the deploy loaded
an empty tarball without a single red step.

## Two more things that are not about your workflow

- **Scope.** A cache belongs to a **ref**, not to a workflow or a job. Every workflow on
  that branch reads every cache on it; a pull request also reads the base branch,
  read-only; a fork's pull request gets the default branch scope read-only. So a restored
  cache is **untrusted input**, and a secret never goes in one.
- **Limits.** 10 GB per repository, entries evicted after 7 days unread. Not storage.

## The exception, because somebody always asks

On a **self-hosted** runner with a persistent disk, files really do survive between jobs.
That is not a feature to lean on — it is the warm-disk trap: the next job inherits the
last job's leftovers, including anything a previous pull request left behind.

## Where this goes next

- `../pipeline/10-cache-deps/` — the dependency cache, keyed properly, across three OSes
- `../pipeline/11-cache-layers/` — the **other** cache: Docker layers, `mode=max`, `scope`
- `../pipeline/12-cache-testcontainers/` — the same test cold and warm, two numbers
- `../by-hand/cache.yml` — `sha256sum`, `tar`, an HTTP call. That is the whole action
