# Migrating an existing CI to the deduplicated triggers

Applies to a repo already scaffolded (by an older version of this skill, or by hand)
whose `ci.yml` runs on **both** `pull_request` and `push` for `develop`. That duplicates
Actions minutes: every commit reaches `develop` through a PR that already ran the full
suite, so the post-merge `push` run on `develop` re-tests code that already passed.

This is the **non-breaking** half of the cost work — changing `on:` triggers renames
nothing, so no status-check or branch-protection changes are involved. (Job
*consolidation* into a single `checks` job, which renames checks, is the breaking half —
see "Migrating to the consolidated `checks` job" at the end.)

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

To keep it from regressing across repos over time, `ci-baseline-audit` checks this (and the
rest of the baseline) on a schedule — see that skill.

## Also non-breaking: cache the e2e browser download

If the repo has a Playwright e2e job, caching the browser binaries removes 1–2 min of
billed download per run and renames nothing, so it pairs with the trigger dedup above.
That job is owned by `testing-init` — see `testing-init/references/ci-test-job.md`.

## Migrating to the consolidated `checks` job (breaking)

Merging the light jobs — `lint + typecheck` and `unit tests` — into a single `checks` job
saves more minutes (one `npm ci` + checkout instead of several, less per-job rounding).
As of the 5→3 consolidation this is the **scaffold default**, not an opt-in: a fresh
`gh-actions-init` + `testing-init` run now produces `checks` (lint + format:check +
typecheck + unit), plus `integration`/`e2e`/`build` as before. This section is for
retrofitting a repo scaffolded by an *older* version onto that shape.

Unlike the trigger dedup above, this **renames status checks** (`lint + typecheck` /
`unit tests` → `checks`), so it is breaking *for any repo that has required status
checks*. If a required context still names a job that no longer exists, GitHub keeps that
"Required" check pending forever and **the PR can never merge** — even with CI fully green.

### Step 1 — check whether the repo even has required checks

Branch protection (and therefore required checks) is unavailable on free-tier private
repos — the API returns **403**. There, there are no contexts to break, so the rename is a
pure no-op: reshape `ci.yml` and you're done. Check before touching anything:

```bash
REPO=owner/repo
for BRANCH in main develop; do
  echo "== $BRANCH =="
  gh api "repos/$REPO/branches/$BRANCH/protection/required_status_checks" --jq '.contexts' \
    2>/dev/null \
    || echo "  none — 403 (free-tier private) or 404 (protection not set): rename is a no-op"
done
```

If every branch printed the no-op line, skip to "Step 3 — reshape the workflow".

### Step 2 — update the required contexts *before* the workflow lands

If Step 1 listed contexts containing `lint + typecheck` and/or `unit tests`, swap them for
`checks` on each protected branch. The `contexts` field **replaces the whole set**, so
pass every context the branch should still require (drop the two old names, add `checks`,
keep the rest):

```bash
gh api -X PATCH "repos/$REPO/branches/$BRANCH/protection/required_status_checks" \
  -f "contexts[]=checks" \
  -f "contexts[]=production build" \
  -f "contexts[]=integration tests" \
  -f "contexts[]=e2e tests"          # include only the contexts this repo actually has
```

Order matters relative to the merge: update the contexts **first** (or in the same window),
then merge the PR that reshapes `ci.yml`. Do it the other way round and open PRs hang on
the now-orphaned old contexts until you fix protection.

`gitflow-init` owns branch protection and derives contexts from the workflow's live job
names rather than hardcoding them, so a *fresh* scaffold needs none of this — the breakage
only exists on repos whose protection was applied with the older names. For the full
protection object and the 403-fallback message, see
`gitflow-init/references/branch-protection.md`; don't reproduce that logic here.

### Step 3 — reshape the workflow

Collapse `lint-typecheck` (+ the Python `lint`/`typecheck` pair) and the `unit` job into
one `checks` job per `gh-actions-init/references/ci-structure.md`, folding the unit-test
step in per `testing-init/references/ci-test-job.md`. Point `build.needs` at `checks`.
`integration` and `e2e` stay their own jobs.

`ci-baseline-audit` reports each repo's shape (separate jobs vs consolidated) but never
*fails* on it — see that skill — because this migration is a deliberate per-repo step, not
drift.

Once consolidated, decide where *future* checks go — fold into `checks` vs their own
parallel job — by the rule in `ci-structure.md` ("What belongs in the consolidated
`checks` job vs its own job").
