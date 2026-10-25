# Step 8 — contexts, `if:`, and `uses:`

**Files:** `.github/workflows/ci.yml`. Everything else carried unchanged.

```bash
diff -ru -x README.md 7-ci-jobs-and-env 8-ci-contexts-and-if
```

## A context becomes true at a moment

Run it and read the first two steps together.

| Reads | Exists since | Why |
|---|---|---|
| `github.*` | GitHub read the file | it **is** the event |
| `vars.*` · `secrets.*` | always | somebody stored them before this run |
| `needs.*` | the job it names finished | that job had to end first |
| `runner.*` · `job.*` | **a machine was assigned** | there was no machine before |
| `steps.*` | that step ran | it had not run yet |

The step to slow down on:

```
vars.NOPE is [] — empty string, no warning
```

**Reading a context that is not there is not an error.** It is an empty string and the job
carries on. That is where `docker push myimage:` with no tag comes from.

## `if:` is the same expression language

- a step with **no `if:` at all** means `if: success()` — the default nobody typed
- `success()` · `failure()` · `cancelled()` · `always()`, and `always()` survives a cancel
- `steps.<id>.outcome` is the result **before** `continue-on-error`; `.conclusion` is after

Break a test and re-run. `the tests passed` is **skipped**, and the `always()` step still
writes the summary. That pair is the whole lesson.

## `uses: owner/repo/path@ref`

Four parts, each a real thing on GitHub:

| Part | Here | Note |
|---|---|---|
| owner | `actions` | a GitHub account |
| repo | `checkout` | an ordinary repository |
| path | *(none)* | a subfolder may sit here — `owner/repo/path@ref` |
| ref | `@v4` | **a tag, and somebody can move it** |

`@v4` is a pointer. A full commit SHA is the only ref that cannot change under you —
which matters most for an action you do not control.

## Try this

1. Add `if: failure()` to the last step and watch it stop running on a green build.
2. Change `@v4` to `@v3` and read what breaks in the log.
3. Delete `needs: inspect` and watch `needs.inspect.outputs.tag` become empty, green.
