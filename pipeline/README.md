# The pipeline, one chapter at a time

`docker/` grows the **application**. This grows the **pipeline** — the same `ci.yml`,
seven times, one new segment each. Every chapter exists because the one before it hurt.

| | Chapter | The pain | What it adds | Lines |
|---|---|---|---|---|
| 01 | `01-pull-request` | the branch looked fine; main was red all weekend | **two real jobs on every pull request** — tests, then a docker build that has to start — and `needs` between them | 46 |
| 02 | `02-triggers` | it now runs on a README typo, on every branch | `branches` · `paths` · activity `types` · `workflow_dispatch` with inputs · `schedule` | 83 |
| 03 | `03-actions` | the same four steps pasted in three files, one still on 3.9 | `uses:` at a tag · pinning by sha · **your own composite action** · artifacts | 93 |
| 04 | `04-real` | two green ticks publish nothing | `needs` as a **graph** · job `outputs` · `matrix` · `concurrency` · `permissions` · publish only from `main` · a digest smoke test | 171 |
| 05 | `05-expressions` | the deploy went to `""` and reported success | `${{ }}` vs `$VAR` · `toJSON` · the empty-key trap · `$GITHUB_ENV`/`PATH`/`STEP_SUMMARY` · the rest of the `if:` family | 212 |
| 06 | `06-environments` | one repository secret was reachable from a workflow added on Tuesday | `env` at three levels · `vars` · `secrets` · `environment:` | 245 |
| 07 | `07-reusable` | four repositories run the same test-and-build pair | **a reusable workflow** — `workflow_call`, `jobs.<id>.uses:`, typed inputs, `secrets: inherit`, outputs that come back | 199 |

**The diff is the lesson:**

```bash
diff -u pipeline/03-actions/ci.yml pipeline/04-real/ci.yml
```

## The two shared things, and why there are two

| | composite action | reusable workflow |
|---|---|---|
| made of | **steps** | **jobs** |
| lives at | `.github/actions/<name>/action.yml` | `.github/workflows/<name>.yml` |
| called from | a `steps:` list — `uses: ./.github/actions/x` | a job — `jobs.<id>.uses: ./.github/workflows/x.yml` |
| runner | **the caller's** — same machine, same disk | **its own**, one per job, in parallel |
| the code | already checked out by the caller | it checks out itself; it shares nothing |
| can it fan out | no | yes — a `matrix` inside it, or at the call site |
| secrets | ordinary inputs, visible in the log unless masked | named, or `secrets: inherit` |

Chapter 03 introduces the first, chapter 07 the second. `install-and-test` stays a
composite action **inside** the reusable workflow, which is the normal arrangement: steps
compose into a job, jobs compose into a workflow.

## None of these are running

GitHub reads workflows from **`.github/workflows/` at the repository root** and nowhere
else. Everything in here is reading material — a `ci.yml` in a subfolder is a text file.

`.github/workflows/ci.yml` is chapter 07, the end state. To demo an earlier one:

```bash
cp pipeline/02-triggers/ci.yml .github/workflows/ci.yml
git commit -am "chapter 2" && git push
```

## The four that are not chapters

`08-on-main.yml`, `09-from-outside.yml`, `10-message-routes.yml`, `11-anchors.yml` and
`12-docs-pages.yml` sit
in `.github/workflows/` as files of their own. Each is a **different subscription**, not a
bigger pipeline — folding them into `ci.yml` would make it longer without making it
better.

`08-on-main.yml` is the other half of chapter 01: a pull request and a merge are two
events, two files and **two different commits**.

`12-docs-pages.yml` is the other half of chapter 02's `paths:` filter. `ci.yml` takes
`ci-base-app/**`, the docs workflow takes `docs/**`, and one push matches exactly one of
them — which is the only arrangement in which a path filter is obviously worth having. It
is also where `permissions:` stops being ceremony: `pages: write` to deploy, and
`id-token: write` so the deploy can prove which run it is instead of holding a key.
