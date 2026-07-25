# Verifying CI cost changes with real numbers

How to prove a cost change actually saved minutes, using GitHub's own billing figures
rather than estimates. Companion to `ci-cost-migration.md` (which makes the changes) —
this file measures them.

Separate concerns on purpose: the migration changes CI, this verifies it. Do the migration
without this and you're guessing; the guess is usually directionally right and numerically
wrong.

## Pricing constants

- `ubuntu-latest` → **$0.008 / billed minute** (Linux, 1× multiplier). Windows is 2×,
  macOS 10× — check `runs-on` before assuming.
- GitHub rounds **each job** up to the next whole minute, then sums jobs per run. This is
  why job count matters as much as job duration: five 20-second jobs bill five minutes.
- Free tier depends on plan (2,000 min/month on Free for private repos). Public repos run
  free on standard runners.

## Source of truth: the timing endpoint

`billable.UBUNTU.total_ms` is GitHub's own billed time for a run, already rounded per job.
Don't compute duration from timestamps — that ignores rounding and queue time.

```bash
# billed Ubuntu ms for one run
gh api "repos/<owner>/<repo>/actions/runs/<RUN_ID>/timing" --jq '.billable.UBUNTU.total_ms'
```

List recent runs and their ids, filtered to the fields that matter:

```bash
gh api "repos/<owner>/<repo>/actions/workflows/ci.yml/runs?per_page=40" \
  --jq '.workflow_runs[] | {id, event, head_branch, created_at, conclusion}'
```

Per-job breakdown (to attribute a change to a specific job):

```bash
gh api "repos/<owner>/<repo>/actions/runs/<RUN_ID>/timing" \
  --jq '.billable.UBUNTU.job_runs[] | {job_id, duration_ms}'
```

## Baseline (BEFORE the change)

1. Take the last ~15–20 **completed** runs from before the change. Include both
   `pull_request` and `push` events — total spend is the point.
2. Record billed minutes per run (`total_ms / 60000`).
3. Compute the averages below over a representative window.
4. Cross-check the monthly total against **Settings → Billing → Actions usage**. If they
   disagree wildly, you're sampling the wrong window or missing a workflow.

| Metric (BEFORE)                   | Value | How measured                         |
| --------------------------------- | ----- | ------------------------------------ |
| avg billed min / PR run           |       | mean of `pull_request` runs          |
| avg billed min / develop push run |       | mean of `push`@develop runs          |
| billed min per merged feature     |       | sum of the runs one feature triggers |
| CI runs / month                   |       | count over a 30-day window           |
| billed min / month                |       | sum over the same window             |
| $ / month                         |       | (min − free allowance) × rate        |

## After the change

Re-run the same queries on runs created *after* each change. Measure in **two steps** so
savings attribute correctly:

- **After the trigger dedup:** `push`@develop runs should disappear entirely. Confirm by
  count, not by feel.
- **After the browser cache:** `e2e` billed minutes drop — but **measure the 2nd+ run**,
  since the first repopulates the cache and is a miss by definition.
- **After job consolidation:** per-run minutes drop again as one job replaces several.
  Compare the per-job breakdown before vs after.

| Metric (AFTER)                | Value | Δ vs before |
| ----------------------------- | ----- | ----------- |
| avg billed min / PR run       |       |             |
| develop push runs / month     |       | should be 0 |
| billed min per merged feature |       |             |
| billed min / month            |       |             |
| $ / month                     |       |             |

Report both the **% reduction per run** and the **projected $/month** at the observed run
volume — a percentage alone hides whether it's worth anything.

## Gotchas

- **`billable` can read `0`.** Immediately after a run, and for runs GitHub counts as
  included rather than billed, `total_ms` comes back `0`. That is *not* "it cost nothing" —
  don't quote a savings figure from it. Wait for the run to finalize, or fall back to the
  Billing page for the period.
- **The first post-cache run is a cache miss.** Using it as the "after" number understates
  the saving to roughly zero.
- **Per-job rounding dominates short jobs.** A job that runs 20 seconds bills a full
  minute, so merging four short jobs saves ~3 minutes/run before any work is deduplicated.
- **Changes only affect future cycles.** If the current cycle already exceeded the free
  allowance, the savings appear next cycle, not now.
- **Don't measure across a runner-type change.** A repo that moved from `ubuntu-latest` to
  a larger runner changes the multiplier; the comparison is meaningless without noting it.

## Keeping it from regressing

Verifying once proves the change worked. It doesn't keep it working — a later PR can
re-add a `push` trigger or a new workflow can reintroduce the duplicate. The
`ci-drift-audit` skill checks the baseline on a schedule; wire it up once the numbers look
right.
