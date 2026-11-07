# reuse — the two units, and the thing that is not one

| File | What it shows |
|---|---|
| `../.github/workflows/_build-and-test.yml` | a **reusable workflow**: made of jobs, called with `jobs.<id>.uses:`, its own runners and its own checkout. The underscore says nothing triggers it |
| `both-units.yml` | both units in one screen — a composite action used as a **step**, a reusable workflow used as a **job** |
| `anchors.yml` | YAML `&` defines and `*` repeats — and why it is the wrong fix: an anchor never leaves its file |

**The reusable workflow cannot live in this folder**, and that is itself the lesson: a
workflow is only callable from `.github/workflows/`, so `_build-and-test.yml` stays there
with the finished pipeline even though nothing triggers it. A composite action has no such
rule — it is a folder with an `action.yml` and can live anywhere, which is why both of
ours sit in `../.github/actions/`:

| Action | What it is |
|---|---|
| `install-and-test` | steps, run on the caller's runner and the caller's disk |
| `qa` | one QA pack, with a step-level `if:` on the environment input |

| | composite action | reusable workflow |
|---|---|---|
| made of | **steps** | **jobs** |
| lives at | `.github/actions/<name>/action.yml` | `.github/workflows/<name>.yml` |
| runner | **the caller's** | **its own**, one per job |
| the code | already checked out | it checks out itself |
| can it fan out | no | yes |
