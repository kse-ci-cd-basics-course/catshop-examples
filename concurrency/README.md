# Concurrency — one use case per file

GitHub's default is **run as much as possible, all at once**, and it has been doing you a
favour in every chapter so far. It stops being a favour the moment two runs touch **the
same thing**.

These are not chapters: nothing here grows into the next file. Each one is a different
answer to a different question, and the last one is the case where a concurrency group is
**not the answer at all**.

| | File | What is shared | Cancel? |
|---|---|---|---|
| 01 | `01-one-deploy-per-environment.yml` | one **environment** | no — queue |
| 02 | `02-one-suite-per-dataset.yml` | one **dataset** | no — queue |
| 03 | `03-migration-main-only.yml` | one **database schema** — and the group is not enough | no — queue, *and* filter the trigger |
| 03b | `03b-migration-check-on-pr.yml` | nothing | **yes** — cancel freely |

---

## 01 · One deployment per environment

**The pain.** Two merges land ninety seconds apart. Both deploy jobs start. The **older**
run finishes last, so the older code is what is live — and both runs are green in the
Actions tab. Nothing is red, nothing is logged, and the only way anybody finds out is by
reading the application.

**The guard.** A group named after the **environment**, not after the workflow or the
branch:

```yaml
concurrency:
  group: deploy-${{ inputs.environment || 'sandbox' }}
  cancel-in-progress: false
```

GitHub's own wording: *"you can use concurrency so that an environment has a maximum of
one deployment in progress at a time."*

**Why `false`.** A half-applied deploy is worse than a late one, so the second run waits
instead of killing the first. Note that GitHub's documentation presents `true` as simply an
option and does not warn about this — the rule is ours, and the reason is the one above.

**Why on the job and not the workflow.** Only this job touches the environment. Put the
group at the workflow root and you also serialise the tests, which share nothing.

---

## 02 · One suite per dataset

**The pain.** The QA suite seeds the shop with three cats, then asserts the shop has three
cats. Two runs start on sandbox at once: both seed, both assert three, both see **six**.
Both go red.

**Neither run is wrong.** There is no bug in the suite and no bug in the shop — the test is
correct and the result is false. That is the most expensive kind of failure there is,
because people go looking in the application.

**The guard.** A group naming the **dataset**:

```yaml
concurrency:
  group: qa-dataset-${{ inputs.environment }}
  cancel-in-progress: false
```

**Why it is a different group from 01.** A deploy and a suite may safely overlap with each
other. Two suites may not. The group names *the thing being mutated*, which is why one
environment can legitimately carry several groups.

**Why `false`, second reason.** A suite killed half way through has already seeded its rows
and will never reach its teardown. Cancelling does not undo it — it leaves the mess for the
next run.

---

## 03 · The case a concurrency group does **not** fix

**The pain.** Barsik opens a pull request. Marsik opens a pull request. Both branches add a
migration script, and both pipelines deploy to sandbox to try the change out.

Now count the groups. Barsik's run is `deploy-sandbox`. So is Marsik's — so **01 already
saves them**: one waits for the other. The group did its job.

And the database is still wrong. Two different migrations were applied in whichever order
the queue happened to pick, from two branches that have never been merged, against a schema
that now matches **neither** pull request. The group serialised them. It did not stop them.

> **A concurrency group answers *how many at once?*. It cannot answer *who is allowed to do
> this at all?*** — and that is the question a migration asks.

**The guard is the trigger, not the group.** The thing that applies a migration subscribes
to one branch and one path, which you already know how to write:

```yaml
on:
  push:
    branches: [main]          # never from a pull request, never from a branch
    paths:
      - 'migrations/**'       # and only when a migration actually changed
  workflow_dispatch:          # break-glass, deliberately manual
```

A pull request touching `migrations/**` matches **nothing** here. There is no run to queue,
so there is nothing to serialise.

**Two keys, two questions:**

| Key | Answers |
|---|---|
| `on.push.branches` + `on.push.paths` | **who** may change it |
| `concurrency.group` | **how many** at a time |

You need both. The filter stops the wrong runs existing; the group stops the right ones
overlapping.

**The group is still there**, and it names the database rather than the environment —
because a cancelled migration is a half-migrated schema, and that is the one in this folder
that must most certainly queue.

---

## 03b · What a pull request gets instead

Blocking the apply is only half an answer: a contributor still needs to know their
migration is valid before it merges. So the pull request gets a check that **reads** the
script, and a **throwaway database that belongs to that job alone**:

```yaml
concurrency:
  group: migration-check-${{ github.head_ref }}
  cancel-in-progress: true          # the one place in this folder where true is right
```

A pull request build **is** safe to cancel — the commit is superseded and the answer is
already worthless. And a database that dies with the runner is shared with nobody, so there
is no group to write for it.

This is the same split as chapter 04's image: a pull request **builds and does not
publish**. Here it **validates and does not apply**.

---

## The two defaults people get wrong

**`cancel-in-progress` is not the only cancelling that happens.** A **pending** run in the
same group is cancelled whether or not you set it — that key governs only the run already
*in progress*. How many may wait is a different key:

```yaml
concurrency:
  group: deploy-production
  cancel-in-progress: false
  queue: max                  # up to 100 pending; `single` is the default, and holds one
```

`queue: max` together with `cancel-in-progress: true` is **rejected** — you cannot both
queue them all and cancel them. The queue is FIFO by the time a run **started waiting**,
not by when it was dispatched.

**The group is a string nothing validates.** A typo gives you a group of one, silently,
which looks exactly like a working configuration. It is the third such string in this
course, after a cache key and an OIDC subject.

## The idiom, and why

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true
```

A pull request groups by **branch**, so a new push supersedes the old run. A push to `main`
has no `head_ref`, so it falls back to its own `run_id` — a group of exactly one — and
therefore **never cancels another push to main**. Drop the fallback and every merge kills
the merge before it.
