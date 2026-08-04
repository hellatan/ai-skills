---
name: ci-drift-audit
description: Audit one or more repos for drift away from this project's CI baseline — duplicate `push` triggers on develop, missing Playwright browser cache, missing workflow_dispatch or /rebuild, unexpected job names. Use when the user wants to "audit CI", "check for CI drift", "make sure the repos still match the baseline", "why did Actions minutes go back up", or is setting up a recurring/scheduled check across repos. Read-only by default — reports findings, never edits a repo unless explicitly asked to fix.
---

# ci-drift-audit

Checks repos against the CI baseline that `gh-actions-init` and `testing-init` scaffold, and reports where they've drifted. Settings applied by hand across many repos rot silently — a repo gets a new workflow, someone re-adds a `push` trigger, a scaffold predates a change — and the first symptom is a surprise Actions bill.

Read-only by design. It reports; it does not fix unless the user explicitly asks.

## When to trigger

User says any of:

- "audit CI" / "check CI drift" / "are my repos still following the baseline?"
- "why are my Actions minutes creeping back up?"
- "set up a recurring CI audit"
- "check that all repos have `/rebuild`" (or any single baseline item)

## When NOT to use

- Scaffolding CI into a repo that has none — that's `gh-actions-init`.
- Retrofitting the cost changes to one repo you're already working in — that's
  `gh-actions-init/references/ci-cost-migration.md`.
- Auditing branch protection settings themselves — that's `gitflow-init`.

## What this skill does NOT own

- **The baseline itself.** The correct CI shape is defined by `gh-actions-init`
  (`references/ci-structure.md`, `ci-cost-migration.md`, `rebuild.md`,
  `develop-to-main-pr.md`, `tagged-deploy.md`) and
  `testing-init` (`references/ci-test-job.md`). This skill only *checks* against them —
  when the baseline changes, update it there and add a check here.
- **Branch protection / required checks** — `gitflow-init` owns that.
- **Fixing** drift — hand each finding to the owning skill.

---

## Where the audit runs (important)

The check definitions here are generic and public. The **repo list and credentials are
not** — a scheduled audit must live in a **private** repo:

- A public host would publish your private repo names in the workflow file (and in git
  history forever).
- Drift reports name private repos, branches, and CI shape.
- Auditing private repos needs a token with private-repo scope; storing that in a public
  repo where anyone can open PRs is a poor blast radius.

So: **definitions here (public), execution + repo list + secrets in a private repo.**

## Cost

The audit reads workflow files over the API and builds nothing — budget **~1 minute per
run**. Set `timeout-minutes` on the job so a hung run can't quietly consume billed
minutes. Bi-weekly is plenty; weekly is still negligible.

An audit that guards CI cost should not itself become a cost.

## Alerting

**Only alert when drift is found.** A recurring "all green" notification trains the
reader to ignore it, and the one time it matters it gets skimmed past. Silence = healthy.

Do alert loudly on *audit failure* (missing token, API errors) — a silently broken audit
is worse than no audit, because it reads as "no drift."

### The blind spot in "silence = healthy"

That policy has one hole it cannot close from the inside: **"the audit never ran" is
indistinguishable from "everything is clean."** Both are silence. An Actions spending limit,
a disabled workflow, an expired token, or a schedule that quietly stops firing all present
as health.

Loud failure alerts don't help — they only fire if the workflow *runs*.

The fix is a **dead man's switch**: ping an external cron monitor on every run (pass or
fail), and let that monitor alert when a ping **doesn't** arrive. Absence becomes an active
alert instead of something a human has to notice not happening — and "I'd never notice it
was missing" is the correct objection to any design that relies on spotting silence.

Requirements that matter:

- **Ping unconditionally** (`always()`), not only on success — the question is "did this
  run", not "did it pass".
- **Never let it fail the audit** (`continue-on-error`) — the switch is a safety net, not a
  dependency.
- **Keep it optional**, and say so in the log when it's unset, so the runner works without
  it.
- **It must live outside GitHub Actions.** A monitor hosted in the thing it watches goes
  down with it.
- **Match the monitor's schedule to the workflow's cron, in UTC**, with a grace window of a
  day or more — GitHub's scheduler is best-effort and routinely runs late.
- **Test it once by letting a ping lapse.** An untested dead man's switch is itself a silent
  failure.

## The checks

Full detail, rationale, and detection notes: `references/checks.md`.

| # | Check | Severity |
| --- | --- | --- |
| 0 | The CI workflow is found by behaviour, and sits at `ci.yml` | precondition — a miss silently voids checks 1–4 |
| 1 | `push:` triggers must not include `develop`, and must be branch-filtered | **high** — duplicate billed minutes |
| 2 | `pull_request:` covers the branches that receive PRs | **high** — a gap means no CI gate |
| 3 | Playwright e2e job caches browsers | medium — 1–2 min/run |
| 4 | `workflow_dispatch:` present on the CI workflow | low |
| 5 | `/rebuild` workflow present (gitflow repos) | low |
| 6 | `develop → main` promotion workflow present | low (missing no-squash warning: medium) |
| 7 | Jobs consolidated into `checks` | **informational only** — opt-in, breaking |
| 8 | Release-tag verification present and correctly wired | low missing / **high** miswired |
| 9 | Tagged-only deploy can actually fire | **high** scoped package / medium changelog gaps |

Check 7 is reported, never failed: consolidation renames status checks, which is a
breaking change for any repo with required checks. See `ci-cost-migration.md`.

Check 8 splits on purpose. A repo that never got the verification block is a rollout
gap (low); a repo that has it but reads `steps.release.outputs.release_created` /
`.tag_name` with a non-root package path is **high** — those outputs are always empty
there, so it cries "NO TAG created" on every healthy release while its real
tag-missing branch can never fire.

Check 9 covers the failure mode with no symptom at all. Under tagged-only deploys the
tag *is* the trigger, so anything that stops release-please cutting a release also stops
the deploy — silently, on a green run. A subdirectory-scoped package path ignores commits
outside it, and default-hidden `chore`/`docs`/`ci` types make a docs-only promotion
produce an empty changelog, which release-please skips entirely. Either way the release
branch moves ahead of production and nothing fails. It reuses check 8's read of the
release-please config; the two differ in what they conclude from it. Its fourth shape is
the inverse — a release that ships when it *shouldn't*: an auto-merge step that squash-merges
the release PR without waiting for that PR's checks tags and deploys unverified code, and
`gh pr merge --auto` doesn't fix it on a repo with no required status checks.

## Flow

### 1. Resolve the repo set

Two supported modes — `references/repo-list.md` has the conventional paths, the discovery
snippet, and the trade-off. Never hardcode repo names in this skill.

**Discovery (recommended default).** Enumerate what the token can see, then filter — so
repos created *after* setup are covered automatically:

```bash
gh repo list <owner> --limit 200 --no-archived --source \
  --json nameWithOwner -q '.[].nameWithOwner'
```

**Explicit list.** A checked-in file at the conventional path
`.github/ci-drift-audit/repos.txt` in the private host repo (one `owner/repo` per line,
`#` comments). Use when the set is deliberately narrow, spans owners, or the token can't
enumerate.

Both modes subtract `.github/ci-drift-audit/ignore.txt` if present.

**Always report the resolved count and mode** — `audited 12 repos (discovery, 2 ignored)`.
A hand-maintained list has a silent failure mode: a repo created after setup is never
audited and the report still says "all green." That's the same silently-shrinking-coverage
problem this skill exists to catch, so the audit must not commit it itself.

### 2. Decide whether the repo is in scope, then fetch its workflows

Skip before spending any workflow calls. A repo with no push in ~365 days, or with no
commits at all, cannot be drifting or accruing minutes — report `skipped: <reason>` and
move on. Discovery over a personal account otherwise drowns the report in a decade of
finished work. See `references/checks.md` § *What the audit declines to check*, and
prefer a dormancy threshold over listing the archive by hand.

Then list the workflow directory once and reuse it — both the CI gate and `/rebuild` are
found by scanning it, so one listing plus one fetch per file covers every check.

```bash
gh api "repos/$REPO/contents/.github/workflows" --jq '.[] | select(.type=="file") | .name'
gh api -H "Accept: application/vnd.github.raw" \
  "repos/$REPO/contents/.github/workflows/$NAME"
```

Handle gracefully — these are normal, not errors:

- repo has no `.github/workflows/` at all → **drift**: no CI gate
- CI lives under a different filename (`validate.yml`, `test.yml`) → **drift**: a rename.
  Find it by behaviour and check it anyway — see check 0. Reporting this as "no CI"
  voids checks 1–4 for that repo.
- repo is inaccessible with the current token → `skipped`

Keep `skipped` distinct from `no drift`. Conflating them hides problems.

### 3. Run the checks

Parse the YAML rather than grepping where possible — `on.push.branches` is a structure,
and a grep for `develop` matches comments and unrelated keys. `yq` is the clean tool.

### 4. Report

Group by repo, list only drifted items, and name the fix (or the owning skill) for each.
Keep it compact — a summary someone reads in ten seconds, not a YAML dump. If posting to
a chat webhook, respect its message limit and truncate with a pointer to the run.

### 5. Do not fix

Report only, unless the user explicitly asked for fixes. Then make one PR per repo,
never a direct push to a default branch.

## Adding a check

The list will grow. Keep each check:

- **Cheap** — one API call per repo, no clones or builds.
- **Specific** — names the exact fix, not "CI looks wrong."
- **Severity-tagged** — so the alert can stay quiet about informational findings.
- **Documented in `references/checks.md`** with *why*, so a future reader can tell a real
  regression from a deliberate exception.

## References

- `references/checks.md` — each check: rationale, detection, fix, severity
- `references/repo-list.md` — where the audited set comes from: discovery vs explicit list, conventional paths, token caveats
- `references/audit-token.md` — the read-only PAT: required scopes, why 404 means "no access", and the confirmed cause of a token that authenticates but sees nothing
- Baseline sources: `gh-actions-init/references/{ci-structure,ci-cost-migration,rebuild,develop-to-main-pr,tagged-deploy,release-please}.md`,
  `testing-init/references/ci-test-job.md`
