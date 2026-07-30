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

**Detect — by behaviour, not filename.** Scan every file in `.github/workflows/` for one
triggered `on: issue_comment` that gates on `/rebuild`. Then check whether it sits at the
canonical `.github/workflows/rebuild.yml`; any other name (the known legacy one is
`ci-rebuild-on-comment.yml`) is **present-but-drifted** — report it as a rename
(→ `rebuild.yml`, workflow `name: rebuild`), not as a missing workflow. Matching on the
filename alone reports a renamed-but-present workflow as absent, and a drifted one as
clean — see the warning under check 6 for how that played out in practice.

**Scope.** Default-on for **gitflow repos** (those with a `develop` branch) — skip for
`main`-only repos, which have no bot-PR gap. Don't report its absence as drift there.

**Also worth checking** once present: the file must live on the **default branch** to be
active at all (`issue_comment` workflows only run from the default branch), and the CI
workflow it dispatches must have `workflow_dispatch:` (check 4).

**Fix.** `gh-actions-init/references/rebuild.md`.

---

## 6. `develop → main` promotion workflow — low (missing no-squash warning: medium)

**Why.** Nothing else opens the release PR, so without it every release waits on someone
remembering to open one by hand. Its generated body also carries the no-squash warning,
which is the only thing between a routine merge and permanent branch divergence.

**Detect — by behaviour, never by filename.** Scan *every* file in
`.github/workflows/` for one that runs `gh pr create` with both `--base main` and
`--head develop`. That workflow is the promotion workflow whatever it happens to be
called. Only after identifying it that way, check whether it sits at the canonical path
`.github/workflows/develop-to-main-pr.yml`.

> ⚠️ **Filename matching is how this check fails.** A fleet-wide sweep that grepped for
> `develop-to-main*` silently skipped the one repo whose promotion workflow was named
> `auto-promote.yml`. That repo was the only one left without the no-squash warning, and
> a filename-scoped audit reported it as clean. At least three names have existed in the
> wild (`develop-to-main-pr.yml`, `develop-to-main.yml`, `auto-promote.yml`), so treat the
> name as unknown and match on what the workflow *does*.

Three drift shapes, all **present-but-drifted** rather than missing:

- **Non-canonical filename** — anything that isn't `develop-to-main-pr.yml`. Report as a
  rename (→ `develop-to-main-pr.yml`, workflow `name: develop → main PR`), the same way
  check 5 handles the old `/rebuild` name.
- **Body missing the no-squash warning** — the generated body must lead with
  `## ⚠️ Merge with "Create a merge commit" — NOT squash`. Grep the workflow for
  `NOT squash`. Report this even when the filename is correct; a repo scaffolded before
  the warning existed passes a presence-only check while still carrying the risk.
- **Opens but never refreshes** — older generations `exit 0` when a PR is already open, so
  the body goes stale as soon as `develop` advances, and a stale PR is never closed once
  `develop` falls level with `main`. Detect: no `gh pr edit` call, or no close step.

**Why that warning is load-bearing.** Squash-merging the promotion PR collapses `develop`'s
commits into one *new* commit on `main`, so git stops seeing them as merged. Every later
promotion PR then opens against a stale merge base and reads as permanently "behind", and
the gap compounds each release. This is real divergence — distinct from the harmless
cosmetic behind-ness caused by the merge commit itself, which `develop-to-main-pr.md`
explains.

**Scope.** Gitflow repos without a `stage` branch. Skip `main`-only repos, and skip repos
with a staging topology (`develop → stage → main` needs a different two-workflow setup).

**Fix.** `gh-actions-init/references/develop-to-main-pr.md`.

---

## 7. Job consolidation (`checks`) — informational only

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

## 8. Release-tag verification present and correctly wired — low missing / **high** miswired

**Why.** release-please can merge a release PR, report the run **success**, and create no
tag. Nothing else notices: the merged release PR stays `autorelease: pending`, which makes
every later run abort with `There are untagged, merged release PRs outstanding` — silently,
still green. Releases just stop, and the repo looks healthy the whole time. The `verify-tag`
steps are the only thing that turns that into a failed run and an alert.

**Scope.** Repos that use release-please. Detect that by behaviour, not by filename: scan
every file in `.github/workflows/` for one that `uses: googleapis/release-please-action`.
The config is **not** reliably at `.github/release-please-config.json` either — at least one
repo keeps it at the repo root — so read the `config-file` / `manifest-file` inputs off that
workflow rather than assuming a path. Skip repos with no release-please workflow.

**Two drift shapes, deliberately different severities.**

- **Missing entirely — low.** The release job has no verification steps. Detect: no step in
  that workflow looks up a tag ref (`git/ref/tags`). This is "not rolled out yet," not a
  malfunction, and it will be true of most repos until the rollout finishes — so it must
  stay quiet enough that nobody learns to skim the report. Report it, don't shout.
- **Present but reading the wrong outputs — high.** The block gates on
  `steps.release.outputs.release_created` or `steps.release.outputs.tag_name`. Detect: match
  those keys **only inside a `${{ … }}` expression** —
  `grep -E '\$\{\{[^}]*outputs\.(release_created|tag_name)'`. A bare
  `grep outputs.release_created` reports the **fixed** shape as broken, because the correct
  block carries a comment naming those keys to warn the next reader off them. Verified: that
  naive grep flags the one repo already on the corrected version. Those keys
  only exist when the manifest package sits at the repo **root** — `setPathOutput()` in
  release-please-action namespaces every per-package output as `<path>--<key>` for any other
  path. Cross-check the package path: read the `packages` keys from the config the workflow
  actually points at.
  - **package path ≠ `.`** → **high**. Both keys are permanently empty, so the check alerts
    "release PR merged but NO TAG created" on every healthy release *and* its
    "tag missing" branch is unreachable dead code. The repo is actively lying in both
    directions. Observed live: a 0.26.0 release alerted as a silent freeze seconds after
    its tag was published by the same run.
  - **package path = `.`** → medium. It works today and breaks the moment the package moves
    or a second one is added, which is a one-line fix now and a mystery later.

A correctly wired block reads the tags out of `toJSON(steps.release.outputs)` (selecting
keys that end in `tag_name`) and verifies each against the tag ref on the remote. That form
is config-independent — root, non-root, and per-component monorepo tags all resolve — so
treat its presence as the pass condition.

**Also worth reporting, both low.** The alert is optional plumbing, and its absence is
quiet by design, which is exactly why it needs surfacing:

- `.github/actions/discord-alert/action.yml` missing while the workflow references it — the
  run fails on a missing action rather than alerting.
- The webhook secret named in the workflow not present in `gh secret list`. The composite
  no-ops with a `::warning::` when unset, so the whole alerting path is dead and every run
  still looks green. Read the secret name out of the workflow rather than assuming it —
  the channel is a per-project choice, and repos deliberately use different ones.

> ⚠️ **"Wired" and "the secret exists" are two different checks.** This exact conflation
> has already burned a fleet audit once, on `RELEASE_PLEASE_TOKEN`: the workflow referenced
> the secret correctly, the audit called it clean, and the secret had never been created.
> An unset secret interpolates to an empty string. Check both.

**Fix.** `gh-actions-init/references/release-verification.md`.

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
