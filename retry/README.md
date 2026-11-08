# Retries, and the number that makes them possible

GitHub Actions has **no automatic job retry**. What it has is a button a human presses
and one environment variable — `GITHUB_RUN_ATTEMPT` — that tells a job which attempt it
is in. Everything that looks like an automatic retry is written by somebody.

| File | Shows |
|---|---|
| `01-bounded-retry.yml` | a three-attempt loop with backoff that **fails at the end**, plus `timeout-minutes` at both job and step level |
| `02-attempt-aware.yml` | `GITHUB_RUN_ATTEMPT`, a job that turns the logging up only on a re-run, and why a re-run is only cheap when the cache exists |

## The rules

- **A retry must be bounded.** A cap and a non-zero exit. An unbounded loop turns a
  broken dependency into a six-hour job, and the 6-hour cap is the only thing that stops
  it.
- **A retry that eventually succeeds hides a flake.** Count them: print the attempt into
  `$GITHUB_STEP_SUMMARY` so the flake is visible even when the job is green.
- **Retry the network, not the test.** A retried integration test with no quarantine is
  how a suite becomes decorative.
- **"Re-run failed jobs" keeps the same `GITHUB_RUN_ID`** and increments
  `GITHUB_RUN_ATTEMPT`. The run is the same run; the attempt is not the same attempt.
- **A re-run is only fast if the cache survived.** The save is a post-step and it runs
  only when the job succeeded — so a job that has never passed has never saved, and every
  retry of it pays the full download again. (`../cache/04-cache-keyed.yml`.)
