# Drift checks

Each check: what it looks for, why it matters, how to detect it, and what fixes it. Add
new checks in this format — a check without a documented *why* becomes noise nobody can
triage.

Severity drives alerting: **high** and **medium** are worth waking someone; **low** is
worth a line in the report; **informational** must never fail a run.

---

## 1. `push:` must not include `develop` — high

**Why.** Every commit reaches `develop` through a PR, which already ran the full suite
via the `pull_request` trigger. Re-running CI on the post-merge push to `develop`
re-tests code that just passed — pure duplicate billed minutes, and historically the
single biggest waste in these repos. `push: main` is deliberately kept as a cheap
re-check on the develop→main landing before a release; long-lived integration branches
may also appear.

**Detect.**

```bash
yq '.on.push.branches // [] | .[]' ci.yml     # `develop` present => drift
```

Beware `on` parsing: YAML 1.1 readers coerce a bare `on:` key to boolean `true`. In
Python, `yaml.safe_load(...)[True]`. `yq` handles `.on` correctly; if using another
parser, verify against a known file first.

**Fix.** Remove `develop` from `on.push.branches`, keeping `main` and any
`integration/**`. See `gh-actions-init/references/ci-cost-migration.md` — non-breaking,
renames nothing.

**Legitimate exception.** A repo with no PR flow (direct pushes to `develop`) genuinely
needs the push trigger. Record such repos as exceptions in the host's repo list rather
than muting the check globally.

---

## 2. `pull_request:` covers branches that receive PRs — high

**Why.** The mirror of check 1, pointing the opposite way. If `develop` is missing from
`pull_request.branches`, PRs into `develop` run **no CI at all** — a hole in the gate,
not a cost saving. Worth flagging louder than a wasted minute.

**Detect.**

```bash
yq '.on.pull_request.branches // [] | .[]' ci.yml   # expect main + develop
```

**Fix.** Add the missing branch(es). See `gh-actions-init/references/ci-structure.md`.

---

## 3. Playwright e2e job caches browsers — medium

**Why.** A bare `npx playwright install --with-deps` re-downloads ~100MB+ of browser
binaries on every run: 1–2 min of billed time a cache hit removes.

**Detect.** Only applies if a Playwright job exists (`playwright install` appears). Then
require an `actions/cache` step with `path: ~/.cache/ms-playwright`. Drift =
`playwright install` present **and** no such cache step.

**Fix.** `testing-init/references/ci-test-job.md` has the cache block, including the
conditional install pair (`install-deps` on hit, `install --with-deps` on miss).

**False-positive guard.** A repo may cache via a different mechanism or a custom action.
Match on the cache *path*, not the exact step name.

---

## 4. `workflow_dispatch:` present on the CI workflow — low

**Why.** Without it there's no way to re-run CI except pushing a commit, which costs a
whole fresh run. It's also the dispatch target `/rebuild` falls back to when a branch has
no prior run.

**Detect.**

```bash
yq '.on | has("workflow_dispatch")' ci.yml
```

**Fix.** Add `workflow_dispatch:` to `on:`. See
`gh-actions-init/references/ci-structure.md`.

---

## 5. `/rebuild` workflow present — low

**Why.** ChatOps re-trigger for flaky runs and the bot-PR CI gap. Cheaper than the
alternative (an empty commit = a whole fresh run).

**Detect.** `.github/workflows/rebuild.yml` exists. The legacy name
`ci-rebuild-on-comment.yml` counts as present-but-drifted: report it as a rename
(→ `rebuild.yml`, workflow `name: rebuild`), not as a missing workflow.

**Scope.** Default-on for **gitflow repos** (those with a `develop` branch) — skip for
`main`-only repos, which have no bot-PR gap. Don't report its absence as drift there.

**Also worth checking** once present: the file must live on the **default branch** to be
active at all (`issue_comment` workflows only run from the default branch), and the CI
workflow it dispatches must have `workflow_dispatch:` (check 4).

**Fix.** `gh-actions-init/references/rebuild.md`.

---

## 6. Job consolidation (`checks`) — informational only

**Why informational.** Merging the light jobs into one `checks` job saves real minutes
(one `npm ci` + checkout instead of several, less per-job rounding), but it **renames the
status checks**. On any repo with required status checks — public repos, or private on a
paid plan — renaming without updating the required-check list makes PRs hang forever on
checks that never report. That makes it an opt-in migration, not a baseline everyone must
match.

**Report** which shape each repo is in (separate jobs vs consolidated) so the fleet's
state is visible. **Never fail** on it.

**Before consolidating any repo**, check whether required checks exist:

```bash
gh api "repos/$REPO/branches/$BRANCH/protection/required_status_checks" --jq '.contexts' \
  2>/dev/null || echo "none (404) or unavailable (403 — free-tier private)"
```

`gitflow-init` owns branch protection; it derives required contexts from the workflow's
job names rather than hardcoding them, so a *fresh* scaffold adapts automatically. The
breakage is in repos whose protection was applied with the older names.

---

## Reporting shape

Only drifted items, grouped by repo, each naming its fix:

```
hellatan/example-app
  ✗ high    push: includes `develop` — remove it (ci-cost-migration.md)
  ✗ low     no workflow_dispatch on ci.yml
  ℹ         jobs: separate (not consolidated)

hellatan/other-app
  ⚠ skipped no .github/workflows/ci.yml found
```

Keep `skipped` visually distinct from clean. A repo the audit couldn't read is an
unknown, not a pass — the failure mode to avoid is a silently shrinking audit that keeps
reporting "all green."
