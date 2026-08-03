---
name: gh-actions-init
description: Add GitHub Actions to an existing repo — scaffolds the CI structure (a consolidated `checks` job running lint + format check + typecheck, plus a build job), wires release-please for automated versioning and changelogs from conventional commits, and drops a platform-agnostic deploy stub. Use when the user wants to "add CI", "set up GitHub Actions", "wire up release-please", "scaffold deploy workflow", or otherwise bring `.github/workflows/` to a project that doesn't have it yet. Detects existing workflows and extends them rather than replacing. Composes with `testing-init` (which owns the test jobs) and `project-scaffold` (which calls this internally for new projects).
---

# gh-actions-init

Adds the GitHub Actions umbrella to an existing project: CI structure, release-please, and a deploy stub. Extends existing workflows instead of replacing them. Composes with `testing-init` (test jobs) and `project-scaffold` (new-project orchestrator).

## When to trigger

User says any of:
- "add CI" / "set up CI" / "scaffold CI"
- "set up GitHub Actions / workflows"
- "add release-please" / "set up automated releases"
- "scaffold the deploy workflow"
- "wire up the CI/CD pipeline"

## When NOT to use

- Project already has working CI + release-please + deploy — extend manually.
- Bootstrapping a brand-new repo from scratch — use `project-scaffold` (which calls this internally).
- User only wants test runners — use `testing-init`.

## What this skill does NOT touch

- **Test steps/jobs** in CI — `testing-init`'s domain. This skill owns the `checks` **job** (lint, format:check, typecheck) and `build`; `testing-init` folds its unit-test *step* into `checks` and adds `integration`/`e2e` as their own jobs.
- **Pre-commit hooks** — separate concern.
- **Branch protection rules** — `gh api` work, not workflows. Future skill (`gitflow-init`).
- **CLAUDE.md** — separate skill.
- **Local test setup** — `testing-init`'s job.

---

## Flow

### 1. Detect stack and existing state

Read these without asking:

- `package.json` — Node project; inspect `dependencies` for framework, `engines.node`, existing `scripts` (look for `lint`, `format:check`, `typecheck`, `build`).
- `pyproject.toml` / `setup.py` — Python project; check for `[project].version`, dev dep groups.
- `.github/workflows/` — list existing workflows. For each:
  - Note the file name and the `jobs:` keys (so we don't duplicate).
- `package.json` `version` and any `pyproject.toml` `version` — the **starting manifest version** (release-please needs this to match).
- Default branch — `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` (handles `master`, `trunk`, etc.).
- Branches — does `develop` exist on origin? If not, the project is `main`-only and CI triggers should reflect that.
- `RELEASE_PLEASE_TOKEN` secret — `gh secret list` (if scaffolding release-please or develop→main). The scaffolded workflows author their PRs with this PAT instead of `GITHUB_TOKEN`; if it's missing, flag it in the summary and report (see `references/release-please.md`).
- Existing back-merge workflow — scan `.github/workflows/` for one that merges `main` into `develop` (**by behaviour, not filename**: it pushes to `develop` on a `push: main` trigger). Skip scaffolding if present; a second one would fight the first.
- Deploy target + its credential — needed for the tagged-only deploy step folded into `release-please.yml`. **First establish whether the repo is deployed at all.** If it isn't — no service exists yet, the normal state for a fresh scaffold, an internal tool, or a library — the answer is the `RENDER_DEPLOY=false` repo variable (`gh variable list`), **not** a missing-secret callout: the deploy step skips cleanly and releases still tag. If it *is* deployed, check the credential (`gh secret list` — `RENDER_DEPLOY_HOOK_URL` for Render) and flag a missing one as **blocking** alongside `RELEASE_PLEASE_TOKEN`, because deploys-enabled-with-no-credential fails the run by design. If the target isn't Render, scaffold the deploy step commented out. See `references/tagged-deploy.md`.
- Alert webhook secret — `gh secret list` (if scaffolding release verification). The secret name is the project's **choice of Discord channel** (default `DISCORD_GH_ERRORS_WEBHOOK`); if a differently-named `DISCORD_*` secret already exists, offer it as the default instead. Optional; note its presence in the summary. When absent, the alerting composite no-ops with a warning, so no blocking callout is needed (see `references/release-verification.md`).

Surface findings in one line: *"Detected: Next.js 16 + TS, default branch `develop`, package.json version 0.3.1, no existing workflows."*

See `references/detection.md` for the detection cheat-sheet.

### 2. Pick what to add

Five independent decisions:

**a. CI structure** — a consolidated `checks` job (lint + format:check + typecheck) + a `build` job.

If `.github/workflows/ci.yml` exists (e.g., `testing-init` already created one with test jobs): extend by adding only missing structural jobs.

If it doesn't exist: create a fresh `ci.yml` with just the structural jobs. Test jobs are added separately by `testing-init`.

**b. release-please** — `release-please.yml` + `release-please-config.json` + `.release-please-manifest.json`.

If any of these already exist: skip the whole release-please piece (don't risk breaking a working release flow). Surface the skip in the report.

If they don't exist: scaffold all three. Manifest version must match `package.json` / `pyproject.toml` version exactly — read the current version, don't hardcode it (fresh `project-scaffold` runs seed `0.1.0`, never `0.0.0`, to avoid release-please's `1.0.0` first-release bootstrap — see `references/release-please.md`). The workflow **must** set `target-branch: main` — in a gitflow repo `develop` is the default branch, and an unset `target-branch` defaults to it, so release-please silently opens release PRs against `develop` and never tags `main` (see `references/release-please.md`). The workflow **must** also pass `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}` — bot-authored release PRs park their CI behind a manual "Approve and run" gate and never trigger it in the first place; the PAT-backed repo secret is a required per-repo setup step (see `references/release-please.md`).

Two config settings are **not optional** for any repo that deploys: scope the package to the repo **root** (`"."`, never the app subdirectory — a subdirectory scope makes changes elsewhere in the repo cut no release, so they never tag and never deploy) and set `changelog-sections` un-hiding every commit type (release-please skips a release when the changelog is empty, so a docs/ci-only promotion would never ship). Both in `references/release-please.md`.

Scaffold the **tagged-only deploy** in the same step — a deploy step plus an auto-merge-the-release-PR step folded into `release-please.yml`, and platform auto-deploy turned off. This is what makes `main == production` true. See `references/tagged-deploy.md`.

Scaffold **release verification** alongside release-please (same skip condition): the `verify-tag` steps folded into `release-please.yml`, plus `release-health.yml` and the `.github/actions/discord-alert` composite. It emits the `released` output the deploy step gates on, so it is a hard prerequisite for both the deploy and the auto-merge, not an optional extra. This fails the run + alerts when a merged release PR produces no tag — the prerequisite for ever auto-merging release PRs. **Ask which secret holds the alert webhook** and substitute it for the `<ALERT_WEBHOOK_SECRET>` placeholder in every scaffolded file — a webhook URL points at one channel, so the secret name is how this project picks where its alerts land. Default to `DISCORD_GH_ERRORS_WEBHOOK` when they have no preference. The secret itself is **optional** — alerts no-op with a warning when it's unset, so the release pipeline works regardless. See `references/release-verification.md`.

**c. Deploy** — folded into `release-please.yml` by default; the standalone `deploy.yml` stub is the fallback.

Default: the tag-gated deploy step from `references/tagged-deploy.md`, in the same job that cuts the tag. **Don't** scaffold a `deploy.yml` on `on: push: tags` unless the deploy genuinely needs its own workflow (build matrix, `environment:` approval gate, per-component fan-out) — a tag pushed with `GITHUB_TOKEN` never fires that trigger at all.

If a `deploy.yml` already exists: skip with a "you already have a deploy workflow" note, and mention that the tagged-only model would fold it into `release-please.yml`.

If a standalone stub *is* wanted: scaffold it from `references/deploy-stub.md`. It lists Render, Vercel, Fly.io, Railway, GHCR, and SSH/rsync as commented alternatives, all on equal footing (each needs user-supplied credentials), with a "How to use this file" header that walks the user through picking a target and adding the secrets it needs.

**d. develop → main auto-PR** — `develop-to-main-pr.yml`, paired with `main-to-develop-backmerge.yml`.

Only relevant when `develop` exists AND there's no `stage` branch (gitflow without staging). Auto-opens/refreshes a draft `develop → main` PR so releases never wait on someone remembering to open it manually. Authors the PR with the same `RELEASE_PLEASE_TOKEN` secret release-please uses. Skip for `main`-only repos and for repos with a `stage` branch (staging topology needs a different two-workflow setup — leave a note). Skip if the file already exists.

**e. /rebuild comment trigger** — `rebuild.yml`.

Default-on for gitflow repos (where `develop` exists). Lets a maintainer re-run failed CI from a PR by commenting `/rebuild` — the manual fallback for flaky runs and for repos where `RELEASE_PLEASE_TOKEN` isn't set up yet (without the PAT, bot-authored PRs never trigger CI and park behind manual approval). Skip for `main`-only repos and if the file already exists (rename legacy `ci-rebuild-on-comment.yml` copies). See `references/rebuild.md`.

### 3. Show summary, halt for confirmation

Render the plan as a fenced code block with emoji headers (same convention as `project-scaffold` Step 8):

```
🔍 Detected:        <stack + branch model + existing workflows>
🤖 CI structure:    <create new ci.yml | extend existing ci.yml: adding [jobs]>
🚀 release-please:  <scaffolding | skipped (already present)>
🔎 release-verify:  <scaffolding (verify-tag + release-health + discord-alert) | skipped (with release-please)>
🚀 Deploy model:    <tagged-only, folded into release-please.yml (target: <platform>) | standalone deploy.yml | skipped (already present)>
🚦 Deploy enabled:  <yes | no — setting RENDER_DEPLOY=false (no service yet; releases still tag, deploy step skips)>
🤝 Release auto-merge: <on (pause with the RELEASE_AUTOMERGE repo variable) | off>
🔁 develop→main PR: <scaffolding | skipped (main-only / staging / already present)>
🔙 main→develop back-merge: <scaffolding | skipped (main-only / staging / already present)>
🔁 /rebuild trigger: <scaffolding | skipped (main-only / already present)>
🔑 RELEASE_PLEASE_TOKEN: <secret present | ⚠️ MISSING — setup required before first release>
🔑 Deploy credential (<e.g. RENDER_DEPLOY_HOOK_URL>): <secret present | not needed yet (deploys gated off) | ⚠️ MISSING while deploys are enabled — tagged releases will fail>
🔔 Alerts → <CHOSEN_SECRET_NAME>: <secret present | not set — alerts no-op until added (optional)>
📝 Files to write:  <list>
📝 Files to extend: <list>
🌿 Branch triggers: <main only | main + develop | main + develop + stage>
```

End with: *"Reply 'yes' / 'go' / 'looks good' to proceed, or tell me what to change."*

### 4. **HALT for confirmation**

Same gate as `project-scaffold` and `testing-init`. Wait for explicit affirmative reply.

---

## Execution

### 5. CI structure

See `references/ci-structure.md` for the per-stack job templates and the extend-vs-create logic. The `push` trigger is `[main]` only (never `develop`) — a PR already runs CI before merge, so a post-merge `push` run on `develop` is pure duplicate minutes. To retrofit an existing repo that still runs `push` on `develop`, see `references/ci-cost-migration.md`.

Per-stack job set:
- **Node/TS**: a `checks` job (lint + optional `format:check` if `prettier` is in dev deps + typecheck) with an insertion point where `testing-init` folds the unit-test step in, plus a `build` job.
- **Python**: a `checks` job (ruff check + ruff format --check + mypy if it's installed), no build job (Python apps usually deploy source).
- **Fullstack**: a `checks` job per side (`frontend-checks`, `backend-checks`), gated by changed-paths if needed.

**Extend-mode rules** (when `ci.yml` exists):
- Add only jobs whose `name:` doesn't already appear.
- Don't change `on:` triggers if they exist — log a warning if they look stale (e.g., only `main` when `develop` exists).
- Match the existing file's indentation (default 2 spaces).
- Preserve any existing `concurrency:` or `permissions:` blocks.

### 6. release-please

See `references/release-please.md`.

Three files:
1. `.github/workflows/release-please.yml` — the workflow.
2. `.github/release-please-config.json` — release type, package name, changelog path.
3. `.github/.release-please-manifest.json` — current version, **must match** `package.json` / `pyproject.toml`.

Skill behavior:
- If `package.json` has `"version": "0.3.1"`, manifest should be `{".": "0.3.1"}` so release-please's first PR generates a clean changelog from the most recent tag.
- For monorepos with separate frontend/backend versions: see `references/release-please.md` monorepo section.

Config must root-scope the package (`"."`) and carry the full `changelog-sections` list — see `references/release-please.md` for why each is load-bearing rather than cosmetic. For a monorepo with one deployable app, add `extra-files` mirroring the root version into the app's `package.json`.

Scaffold **release verification** in the same step (skip it whenever release-please is skipped). Two extra files — `.github/workflows/release-health.yml` and `.github/actions/discord-alert/action.yml` — plus the `verify-tag` steps + `concurrency` block folded into `release-please.yml`. All templates, the `<ALERT_WEBHOOK_SECRET>` substitution, and the (optional) secret guidance are in `references/release-verification.md`.

### 7. Tagged-only deploy

See `references/tagged-deploy.md` — the canonical design; don't restate or improvise it.

Two more steps folded into the same `release-please.yml` job, plus one platform setting:

1. **Deploy tagged release** — gated on `steps.check.outputs.released == 'true' && vars.RENDER_DEPLOY != 'false'`, deploying `github.sha`, which *is* the commit release-please just tagged. Render is the verified path (POST the deploy hook with `&ref=<sha>`, `RENDER_DEPLOY_HOOK_URL` secret, fail loudly if unset **while deploys are enabled**). Vercel/Netlify/Cloudflare and generic-CI/AWS variants exist in the reference **commented out and marked unverified** — scaffold them that way; never present them as tested.
2. **Auto-merge the release PR** — squash-merge via `RELEASE_PLEASE_TOKEN` (a `GITHUB_TOKEN` merge wouldn't re-trigger the workflow, so no tag would ever be cut), finding the PR by its `autorelease: pending` label rather than the action's `pr` output. Pause switch: repo variable `RELEASE_AUTOMERGE=false`.
3. **Turn off the platform's native branch auto-deploy** (`autoDeploy: false` in `render.yaml`, or the equivalent dashboard setting elsewhere). **Existing service:** the file alone does nothing — say plainly in the report that the setting must also be flipped in the platform dashboard (or the Blueprint re-synced). **Brand-new service created from a Blueprint that already carries `autoDeploy: false`:** it starts off; don't send the user chasing a toggle that's already correct.

**Set `RENDER_DEPLOY=false` whenever the repo has no deploy target yet.** A repo with no service has no deploy hook to configure, and without the gate its first tagged release would fail the release workflow — on something that was never deployed. With the gate, the release chain works from day one and only the deploy step is dormant. Give the go-live checklist (create service → add secret → delete the variable) from `references/tagged-deploy.md` in the report.

Net: one human gate (merging the `develop → main` promotion PR) → release → tag → deploy of the exact tagged commit, exactly once.

### 8. develop → main auto-PR (gitflow, no staging)

See `references/develop-to-main-pr.md`.

One file: `.github/workflows/develop-to-main-pr.yml`. Scaffold it only when `develop` exists and no `stage` branch does. It needs Actions to be allowed to open PRs — `project-scaffold` enables this on fresh repos; for an existing repo, surface the one-time `gh api` enable command from the reference doc in the report. Skip with a note for `main`-only repos and for repos using a `stage` branch.

Scaffold the **main → develop back-merge** in the same step, under the same condition — see `references/main-to-develop-backmerge.md`. One file: `.github/workflows/main-to-develop-backmerge.yml`. The two are a pair: the promotion workflow pushes `develop`'s work onto `main`, and the back-merge returns what `main` accumulates (the promotion merge commit, release-please's CHANGELOG + version bump) so `develop` never drifts and the promotion PR never sits behind an *Update branch* click. It **must** fast-forward before falling back to `--no-ff`; a merge commit on the fast-forwardable path turns the promotion workflow into an endless loop of empty PRs, and that reasoning is the load-bearing part of the reference doc.

### 9. /rebuild comment trigger (gitflow)

See `references/rebuild.md`.

One file: `.github/workflows/rebuild.yml` (workflow `name: rebuild`, matching the `/rebuild` command). Scaffold it only when `develop` exists (gitflow) — it lets a maintainer re-run failed CI from a PR by commenting `/rebuild`, the manual fallback now that `RELEASE_PLEASE_TOKEN` handles bot-PR CI automatically. Adapt the dispatch-fallback target to the repo's CI workflow filename (`ci.yml`, or `validate.yml` for a docs/skills repo). Skip for `main`-only repos and if the file already exists.

### 10. Smoke-validate

Don't run actual workflows from the skill (would require pushing). Instead:

- `actionlint .github/workflows/*.yml` if `actionlint` is installed (`brew install actionlint`); otherwise skip with a note.
- `gh workflow list` to confirm GitHub picks up the new workflows after first push.

Don't fail the skill if these tools aren't available — they're nice-to-haves.

### 11. Report back

Print:
- ✅ What was added (file paths)
- ✅ What was extended (job names added to existing files)
- ✅ What was skipped and why (existing release-please, etc.)
- ⚠️ Anything that needs user attention (e.g., stale `on:` triggers in existing CI; missing `engines.node`)
- 🔑 **If `RELEASE_PLEASE_TOKEN` is missing** (Step 1 check): a **blocking chat callout, not a buried list item** — the scaffolded `release-please.yml` / `develop-to-main-pr.yml` fail with an auth error until the secret exists. Give the exact command and the PAT requirements (fine-grained PAT, Contents + Pull requests: read/write, repo in its access list):

```bash
gh secret set RELEASE_PLEASE_TOKEN --repo <owner>/<repo>
```

- 📋 Next steps:

```
Next steps:
1. (If flagged above) Add the RELEASE_PLEASE_TOKEN repo secret — the release workflows fail without it
2. Push a feature branch and open a PR — confirm CI runs green
3. Deploys: if this repo has no hosting service yet, nothing to do — the RENDER_DEPLOY=false
   repo variable keeps the deploy step dormant while releases still tag. When you do go live:
   create the service (a fresh one from the committed config already has auto-deploy off; an
   EXISTING service must be toggled off in the dashboard — the file alone does nothing), add
   the deploy-hook secret, then delete the RENDER_DEPLOY variable. Next release deploys itself.
4. (If you don't have tests yet) Run `/testing-init` to fold the unit-test step into `checks` and add the `integration` / `e2e` jobs
5. (If you want branch protection on main/develop) Set it up via GitHub UI or `gh api repos/{owner}/{repo}/branches/{branch}/protection`
6. Make your first conventional commit (`feat:`, `fix:`, etc.) — release-please tracks these for the next release PR
7. (If develop→main auto-PR was scaffolded) Confirm Actions can open PRs — `project-scaffold` enables this; for an existing repo run the `gh api ... actions/permissions/workflow` command in `references/develop-to-main-pr.md`
8. (If develop→main auto-PR was scaffolded) Merge the `develop → main` promotion PR with **"Create a merge commit"**, never squash — squashing breaks `develop`'s ancestry into `main` and hides the conventional commits release-please needs, and undoing it takes a force-push of `main`. The generated PR body says so at the top; see "Never squash the promotion PR" in `references/develop-to-main-pr.md`
```

---

## Token split across workflows

Three scaffolded workflows, two tokens. The split is deliberate:

| Workflow | Token | Why |
|---|---|---|
| `release-please.yml` | `RELEASE_PLEASE_TOKEN` | the release PR must be user-authored so CI runs (and isn't parked behind `action_required`) — **and** the auto-merge step must use it, since a `GITHUB_TOKEN`-authored merge wouldn't re-trigger the workflow that cuts the tag |
| `develop-to-main-pr.yml` | `RELEASE_PLEASE_TOKEN` | the `develop → main` PR needs CI for the same reason |
| `rebuild.yml` | `GITHUB_TOKEN` | uses `gh run rerun` + `gh workflow run` (`workflow_dispatch`), both exempt from the recursion guard — a PAT adds nothing |

One PAT secret (`RELEASE_PLEASE_TOKEN`) covers both PR-authoring workflows; `/rebuild` stays on the built-in token. See `references/release-please.md` and `references/rebuild.md`.

## Reference files

- `references/detection.md` — how to read stack + existing workflows + version state + branch model
- `references/ci-structure.md` — the per-stack `checks` job (lint + format:check + typecheck) + build; the `testing-init` insertion point; extend-vs-create logic
- `references/ci-cost-migration.md` — retrofit an existing repo to the deduplicated `push` triggers (non-breaking); notes on the separate, breaking job-consolidation change
- `references/ci-cost-verification.md` — prove a cost change worked using GitHub's own billed minutes (`runs/{id}/timing`): before/after tables, pricing constants, and the gotchas (a `0` billable reading is not "free")
- `references/release-please.md` — workflow, config, manifest; monorepo variant; tag-pattern gotchas
- `references/release-verification.md` — `verify-tag` (folded into `release-please.yml`) + `release-health.yml` + `discord-alert` composite: fail-loud + Discord alert when a merged release PR produces no tag; the alert channel is a scaffold-time choice (`<ALERT_WEBHOOK_SECRET>`, default `DISCORD_GH_ERRORS_WEBHOOK`, optional)
- `references/develop-to-main-pr.md` — `develop-to-main-pr.yml`: auto-opens/refreshes the draft `develop → main` release PR (gitflow without staging)
- `references/main-to-develop-backmerge.md` — `main-to-develop-backmerge.yml`: fast-forwards `develop` to `main` after every promotion/release so it never drifts; conflict opens a PR and notifies the PR channel (`<PR_ALERT_WEBHOOK_SECRET>`, default `DISCORD_PR_ALERTS_WEBHOOK`, optional)
- `references/rebuild.md` — `rebuild.yml`: `/rebuild` PR-comment re-runs failed CI (gitflow); pairs with the PAT setup
- `references/tagged-deploy.md` — **the deploy model**: `autoDeploy: false` + tag-gated deploy step + release-PR auto-merge + the two release-please config settings that make every promotion release; the `RENDER_DEPLOY` gate for repos with no deploy target yet + the go-live checklist; the `GITHUB_TOKEN` tag-trigger gotcha; the revert-forward runbook; unverified non-Render platform blocks; multi-deploy-monorepo guidance
- `references/deploy-stub.md` — the fallback standalone `deploy.yml` with the deploy-target picker, secret-setup guidance, and platform examples (Render, Vercel, Fly, Railway, GHCR, SSH/rsync); also the `render.yaml` Blueprint

## Why these defaults

- **Deploys are tagged-only.** Platform branch auto-deploy plus release-please's two-push model ships the *untagged* promotion merge first and then deploys again on the release commit — two deploys per release, the first of which nobody can name a version for. Gating the deploy on a verified tag makes `main == production` an invariant instead of an aspiration. See `references/tagged-deploy.md`.
- **Deploy targets stay platform-neutral.** Only the Render path is verified in practice; every other target is a commented snippet, explicitly labelled unverified, requiring user-supplied credentials and decisions.
- **release-please over manual versioning** — drives off conventional commits, opens PRs you review, no manual tag/changelog work.
- **No build job for Python** — Python apps generally deploy source via container or buildpack; a separate `build` step adds CI time without value. Library projects can opt in by extending the workflow.
- **Idempotent on re-run** — skips files that exist, extends `ci.yml` jobs without duplicating, surfaces what was skipped.
- **Composes cleanly with `testing-init`** — neither skill stomps on the other's CI jobs. Run order doesn't matter.
