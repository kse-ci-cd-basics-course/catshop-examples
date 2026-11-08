# artifacts — what a run leaves behind

`what-a-run-leaves.yml` — a JUnit report, an HTML coverage report, and the image itself as
a tarball handed to a later job without publishing anything.

The rule that decides between this folder and `../cache/`:

> **If a missing file should FAIL the job, it is an artifact.
> If it should only make the job SLOWER, it is a cache.**

An artifact is a zip behind an API you already hold a token for — `../by-hand/artifact.yml`
fetches one with `gh api` and unzips it.
