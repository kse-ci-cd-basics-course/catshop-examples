# Step 7 — more than one job, and where a value lives

**Files:** `.github/workflows/ci.yml`. Everything else is carried unchanged from step 6.

```bash
diff -ru -x README.md 6-ci-build-test 7-ci-jobs-and-env
```

That diff is one file. **The application still has not learned about pipelines.**

## Three jobs, and why there are three

| Job | Costs | Runs when |
|---|---|---|
| `decide` | a few seconds | always. It produces facts the others need |
| `test` | under a minute | after `decide` |
| `package` | a minute or two | **only if `test` passed** |

Cheapest first. `package` says `needs: [decide, test]`, and that one word is what makes
*"the build fails when a test fails"* true rather than something you hope is true. Delete
it and a red test still produces an image.

## `needs:` is the order **and** the channel

A job gets its own machine and that machine is destroyed. Two things cross the boundary,
and `outputs` is the one for small values:

```yaml
decide:
  outputs:
    tag: ${{ steps.name_it.outputs.tag }}   # the JOB re-exports it
  steps:
    - id: name_it                           # the STEP needs an id
      run: echo "tag=${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"
```

- a step appends to **`$GITHUB_OUTPUT`**, which is an ordinary text file — the workflow
  `cat`s it so you can see that for yourself
- the **job** must re-export it under `outputs:`, or nothing leaves the machine
- **every output is a string.** `is_main` is `"true"`, not `true`

Then `needs.decide.outputs.tag` works in any job that declared `needs: decide`. Drop the
`needs:` and the expression quietly becomes an empty string — no error.

## `env:` has three levels, and the nearest one wins

| Level | In this file | Seen by |
|---|---|---|
| workflow | `APP: catshop` | every job |
| job | `APP: catshop-ci` | every step in `test` |
| step | `APP: catshop-probe` | that one step |

The `which APP won` step prints `catshop-probe`. Change one line and re-run it until the
order is obvious — it is cheaper than remembering a table.

**`COUNTER_FILE` is set at job level**, because a runner has no `/data`. Same reason as
step 6: everything comes from the environment.

## What is still missing

No registry, no credentials, no digest. `package` builds an image and throws it away when
the machine dies, which is exactly as useful as it sounds — and is the reason the next step
exists.

## Try this

1. Break a test. Watch `package` **skip**, not fail — and ask what a required check makes
   of a skipped job.
2. Delete `needs: decide` from `package` and watch `${{ needs.decide.outputs.tag }}` become
   an empty string, with the build still green.
3. Move `COUNTER_FILE` from the job up to the workflow and work out which other job just
   inherited it.
