# Migrating an existing CI to the deduplicated triggers

Applies to a repo already scaffolded (by an older version of this skill, or by hand)
whose `ci.yml` runs on **both** `pull_request` and `push` for `develop`. That duplicates
Actions minutes: every commit reaches `develop` through a PR that already ran the full
suite, so the post-merge `push` run on `develop` re-tests code that already passed.

This is the **non-breaking** half of the cost work — changing `on:` triggers renames
nothing, so no status-check or branch-protection changes are involved. (Job
*consolidation*, which renames checks, is a separate breaking change — see the note at
the end.)

## The change

```diff
 on:
   pull_request:
     branches: [main, develop]
   push:
-    branches: [main, develop]
+    branches: [main]            # + any long-lived integration branches; never develop
   workflow_dispatch:
```

Keep `main` in `push`: it's the cheap re-check on the develop→main landing before a
release. If the repo has long-lived integration branches (e.g. `integration/**`) that
receive direct pushes, list those too — just not `develop`.

## When this is safe (which is almost always)

The develop→main **promotion PR** is a `pull_request`, so it still runs the full suite
before anything reaches `main`. Dropping the `push`@develop run removes only the
post-merge re-test of already-green code. The one thing it gives up: on a repo *without*
"require branches up to date before merging" (which includes every free-tier private
repo, where branch protection is unavailable), a PR merged on a stale base lands a
`develop` tree that wasn't tested as a whole. The promotion PR still catches that before
`main` — you lose detection *speed*, not the gate. On a solo repo merging PRs
sequentially the window is negligible.

## Verify the saving with real numbers

Don't estimate — GitHub reports billed minutes per run. Full before/after procedure
(the `runs/{id}/timing` endpoint, baseline/after tables, the pricing constants, and the
gotchas) is in `ci-cost-verification.md`. In short:

```bash
# billed Ubuntu ms for one run
gh api repos/<owner>/<repo>/actions/runs/<RUN_ID>/timing --jq '.billable.UBUNTU.total_ms'
```

After the change, confirm **no** CI run fires on the `push` to `develop` (only the
promotion PR runs), and that the promotion PR still runs the full suite.

## Also non-breaking: cache the e2e browser download

If the repo has a Playwright e2e job, caching the browser binaries removes 1–2 min of
billed download per run and renames nothing, so it pairs with the trigger dedup above.
That job is owned by `testing-init` — see `testing-init/references/ci-test-job.md`.

## Related but separate: job consolidation (breaking)

Merging the lint/typecheck/test jobs into a single `checks` job saves more minutes
(one `npm ci` + checkout instead of several, less per-job rounding) but **renames the
status checks**. That is a breaking change *for any repo that has required status
checks* — i.e. public repos or paid plans. Before doing it there, update the required
checks (remove the old names, add `checks`) or PRs hang on checks that never report.
On a free-tier private repo there are no required checks, so the rename is a no-op.

Check whether the repo actually has required checks *first*; branch protection is owned
by `gitflow-init`. That change is tracked separately from this trigger dedup.
