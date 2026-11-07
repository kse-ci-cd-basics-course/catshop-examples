# triggers — which event, and therefore which run

Four files, four different subscriptions. None of them is a bigger pipeline than the
last; each answers *what makes this run, and what does that say about the commit?*

| File | What it shows |
|---|---|
| `on-main.yml` | the other half of a pull request: a merge arrives as a **push**, on a different commit, and only this one may deploy |
| `from-outside.yml` | the cron that hopes, replaced — `repository_dispatch`, and a run with no commit behind it |
| `message-routes.yml` | 02:00, production down. `build → qa → deploy`, and `[hotfix]` **skips the twenty-minute QA stage**. The `if:` on `deploy` is the lesson: `needs` hides an `&& success()`, so a skipped stage has to be allowed on purpose |
| `docs-pages.yml` | the other half of a `paths:` filter — a docs edit never runs the tests, and `permissions:` finally earns its keep (`pages: write`, `id-token: write`) |

Copy one into `.github/workflows/` to watch it run. The finished pipeline that lives there
subscribes to two events only: `pull_request`, and `push` to `main`.
