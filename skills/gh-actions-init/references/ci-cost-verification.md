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

## First: check whether the timing endpoint returns anything

`/actions/runs/{id}/timing` is *supposed* to report `billable.UBUNTU.total_ms` — GitHub's
own billed time, already rounded per job. When it works, use it.

**It frequently returns zeros.** Measured on a private repo: **347 of 347 runs across a full
month returned `billable.UBUNTU.total_ms: 0`**, with every `job_runs[].duration_ms` also 0.
`run_duration_ms` and `billable.UBUNTU.jobs` were populated normally — only the *billing*
numbers were zeroed. This was not sampling: every run was fetched individually.

So **probe before you build on it**:

```bash
gh api "repos/<owner>/<repo>/actions/runs/<RUN_ID>/timing" --jq '.billable.UBUNTU'
```

- Non-zero `total_ms` → use it, it's authoritative.
- `total_ms: 0` on a run you know took real time → **the endpoint is useless here.** Use the
  job-timestamp method below. Do not average zeros into a result and report a saving.

A `0` never means "this run was free". Treat it as *no data*.

## Fallback that always works: compute from job timestamps

Billed time = **sum over jobs of `ceil(job_duration / 60s)`**. Job start/end timestamps are
always populated, so this is reconstructable even when the billing fields aren't.

```bash
gh api "repos/<owner>/<repo>/actions/runs/<RUN_ID>/jobs" \
  --jq '.jobs[] | {name, started_at, completed_at}'
```

```python
import math, datetime as dt
def billed_minutes(jobs):   # jobs: [(name, started_at, completed_at), ...]
    total = 0
    for name, s, e in jobs:
        secs = (dt.datetime.fromisoformat(e.replace("Z","+00:00"))
              - dt.datetime.fromisoformat(s.replace("Z","+00:00"))).total_seconds()
        total += math.ceil(secs / 60)     # per-JOB rounding, not per-run
    return total
```

Two things this must get right, or the number is wrong:

- **Round each job separately, then sum.** Rounding the total instead badly under-counts —
  five 20-second jobs bill 5 minutes, not 2.
- **Never substitute run wall-clock** (`run_duration_ms`). Parallel jobs make it far smaller
  than billed time, and *consolidating jobs moves the two in opposite directions*: serialising
  work makes wall-clock go **up** while billed minutes go **down**. Measured on a real
  before/after pair — wall-clock 1.79 → 2.53 min per run while billed went 6 → 5.

Label anything from this method as **derived**, not GitHub-reported. It applies the
documented rounding rule but can't account for anything GitHub does silently.

## For the account total, use the billing page

Per-run numbers answer "did cost-per-run drop". They do **not** answer "did this month cost
less" — that needs the account-wide figure, which also covers every other repo sharing the
same allowance.

**Settings → Billing and licensing → Usage**, filtered to the month. There are billing API
endpoints too, but they need account-level (`Plan: Read`) scope that a repo-scoped token
doesn't have — so a workflow can't read them with the same token it audits repos with.

List recent runs and their ids, filtered to the fields that matter:

```bash
gh api "repos/<owner>/<repo>/actions/workflows/ci.yml/runs?per_page=40" \
  --jq '.workflow_runs[] | {id, event, head_branch, created_at, conclusion}'
```

Pagination is capped around **30 per page** regardless of `per_page`, so paginate rather
than assuming one call covers the window.

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
- **Per-job rounding dominates short jobs.** A job that runs 20 seconds bills a full minute.
  This cuts both ways — see the worked example below, where it made consolidation worth far
  less than predicted.
- **Changes only affect future cycles.** If the current cycle already exceeded the free
  allowance, the savings appear next cycle, not now.
- **Don't measure across a runner-type change.** A repo that moved from `ubuntu-latest` to
  a larger runner changes the multiplier; the comparison is meaningless without noting it.

## Worked example: estimate vs. measurement

A real before/after on one repo, kept here because **the estimate was wrong in a way that
generalises**. Both configs measured on the same morning, minutes apart, via the
job-timestamp method.

**Predicted:** ~14 billed min/run → ~10. **Actual:**

| | Jobs | Per-job durations | Billed |
| --- | --- | --- | --- |
| Before | 5 | 92s, 28s, 42s, 56s, 53s | **6 min** |
| After | 3 | 75s, 82s, 57s | **5 min** |

**1 minute per run (~17%), not the ~30% predicted.**

Why the estimate was wrong, and what to take from it:

- **The estimate assumed ~2 min per job. Real jobs were 28–92 seconds.** Every job was
  already at its 1-minute rounding floor, so removing two jobs removed two floors — nothing
  more. Consolidation saves **~1 billed minute per job removed** when jobs are short, no
  matter how much work they do.
- **Merging jobs serialises them.** The surviving `checks` job grew to 75s doing three
  jobs' work, crossing into a second billed minute and handing one of the saved minutes
  straight back.
- So **consolidation scales with job *count*, not job duration** — and on a suite of fast
  jobs most of the theoretical saving evaporates. Estimate it as
  `(jobs_removed − extra_minutes_from_serialising)`, not as a percentage.

By contrast, **the trigger dedup was worth ~6× more**: 31 duplicate `push`@develop runs
eliminated over 24 days, each a full 6-minute run — ~7.8 min/day, versus ~5.7 min/day from
consolidation at that repo's volume. Deleting whole runs beats trimming existing ones.

**Measure before promising a number.** Two API calls give the real figure; a plausible
guess was off by nearly 2×.

## Keeping it from regressing

Verifying once proves the change worked. It doesn't keep it working — a later PR can
re-add a `push` trigger or a new workflow can reintroduce the duplicate. The
`ci-drift-audit` skill checks the baseline on a schedule; wire it up once the numbers look
right.
