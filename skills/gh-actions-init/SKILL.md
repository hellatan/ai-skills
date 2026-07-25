---
name: gh-actions-init
description: Add GitHub Actions to an existing repo — scaffolds the CI structure (lint + typecheck + format check + build), wires release-please for automated versioning and changelogs from conventional commits, and drops a platform-agnostic deploy stub. Use when the user wants to "add CI", "set up GitHub Actions", "wire up release-please", "scaffold deploy workflow", or otherwise bring `.github/workflows/` to a project that doesn't have it yet. Detects existing workflows and extends them rather than replacing. Composes with `testing-init` (which owns the test jobs) and `project-scaffold` (which calls this internally for new projects).
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

- **Test jobs** in CI (unit / integration / e2e) — `testing-init`'s job. This skill scaffolds the *structural* CI jobs (lint, typecheck, format:check, build); test jobs are added separately by `testing-init`.
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
- `DISCORD_GH_ERRORS_WEBHOOK` secret — `gh secret list` (if scaffolding release verification). Optional; note its presence in the summary. When absent, the alerting composite no-ops with a warning, so no blocking callout is needed (see `references/release-verification.md`).

Surface findings in one line: *"Detected: Next.js 16 + TS, default branch `develop`, package.json version 0.3.1, no existing workflows."*

See `references/detection.md` for the detection cheat-sheet.

### 2. Pick what to add

Five independent decisions:

**a. CI structure** — lint + typecheck + format:check + build jobs.

If `.github/workflows/ci.yml` exists (e.g., `testing-init` already created one with test jobs): extend by adding only missing structural jobs.

If it doesn't exist: create a fresh `ci.yml` with just the structural jobs. Test jobs are added separately by `testing-init`.

**b. release-please** — `release-please.yml` + `release-please-config.json` + `.release-please-manifest.json`.

If any of these already exist: skip the whole release-please piece (don't risk breaking a working release flow). Surface the skip in the report.

If they don't exist: scaffold all three. Manifest version must match `package.json` / `pyproject.toml` version exactly — read the current version, don't hardcode it (fresh `project-scaffold` runs seed `0.1.0`, never `0.0.0`, to avoid release-please's `1.0.0` first-release bootstrap — see `references/release-please.md`). The workflow **must** set `target-branch: main` — in a gitflow repo `develop` is the default branch, and an unset `target-branch` defaults to it, so release-please silently opens release PRs against `develop` and never tags `main` (see `references/release-please.md`). The workflow **must** also pass `token: ${{ secrets.RELEASE_PLEASE_TOKEN }}` — bot-authored release PRs park their CI behind a manual "Approve and run" gate and never trigger it in the first place; the PAT-backed repo secret is a required per-repo setup step (see `references/release-please.md`).

Scaffold **release verification** alongside release-please (same skip condition): the `verify-tag` steps folded into `release-please.yml`, plus `release-health.yml` and the `.github/actions/discord-alert` composite. This fails the run + alerts when a merged release PR produces no tag — the prerequisite for ever auto-merging release PRs. The Discord webhook secret (`DISCORD_GH_ERRORS_WEBHOOK`) is **optional** — alerts no-op with a warning when it's unset, so the release pipeline works regardless. See `references/release-verification.md`.

**c. Deploy stub** — `deploy.yml`.

If it exists: skip with a "you already have a deploy workflow" note.

If it doesn't: scaffold the stub. The stub lists Render, Vercel, Fly.io, Railway, GHCR, and SSH/rsync as commented alternatives, all on equal footing (each needs user-supplied credentials), with a "How to use this file" header that walks the user through picking a target and adding the secrets it needs.

**d. develop → main auto-PR** — `develop-to-main-pr.yml`.

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
🚀 Deploy stub:     <scaffolding | skipped (already present)>
🔁 develop→main PR: <scaffolding | skipped (main-only / staging / already present)>
🔁 /rebuild trigger: <scaffolding | skipped (main-only / already present)>
🔑 RELEASE_PLEASE_TOKEN: <secret present | ⚠️ MISSING — setup required before first release>
🔔 DISCORD_GH_ERRORS_WEBHOOK: <secret present | not set — alerts no-op until added (optional)>
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
- **Node/TS**: `lint + typecheck` job, optional `format:check` (if `prettier` is in dev deps), `build` job.
- **Python**: `lint` job (ruff check + ruff format --check), `typecheck` job (mypy if it's installed), no build job (Python apps usually deploy source).
- **Fullstack**: matrix of both, gated by changed-paths if needed.

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

Scaffold **release verification** in the same step (skip it whenever release-please is skipped). Two extra files — `.github/workflows/release-health.yml` and `.github/actions/discord-alert/action.yml` — plus the `verify-tag` steps + `concurrency` block folded into `release-please.yml`. All templates and the `DISCORD_GH_ERRORS_WEBHOOK` (optional) secret guidance are in `references/release-verification.md`.

### 7. Deploy stub

See `references/deploy-stub.md`.

One file: `.github/workflows/deploy.yml`. Triggers on `v*.*.*` tag pushes (release-please creates these on release-PR merge). Render, Vercel, Fly.io, Railway, GHCR, and SSH/rsync are all listed as commented alternatives with a "How to use this file" header explaining how to pick one and wire up its secrets.

### 8. develop → main auto-PR (gitflow, no staging)

See `references/develop-to-main-pr.md`.

One file: `.github/workflows/develop-to-main-pr.yml`. Scaffold it only when `develop` exists and no `stage` branch does. It needs Actions to be allowed to open PRs — `project-scaffold` enables this on fresh repos; for an existing repo, surface the one-time `gh api` enable command from the reference doc in the report. Skip with a note for `main`-only repos and for repos using a `stage` branch.

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
3. Pick a deploy target in `.github/workflows/deploy.yml` and follow the "How to use this file" header inside it to wire up secrets
4. (If you don't have tests yet) Run `/testing-init` to add the test jobs that round out the 5-check pipeline
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
| `release-please.yml` | `RELEASE_PLEASE_TOKEN` | the release PR must be user-authored so CI runs (and isn't parked behind `action_required`) |
| `develop-to-main-pr.yml` | `RELEASE_PLEASE_TOKEN` | the `develop → main` PR needs CI for the same reason |
| `rebuild.yml` | `GITHUB_TOKEN` | uses `gh run rerun` + `gh workflow run` (`workflow_dispatch`), both exempt from the recursion guard — a PAT adds nothing |

One PAT secret (`RELEASE_PLEASE_TOKEN`) covers both PR-authoring workflows; `/rebuild` stays on the built-in token. See `references/release-please.md` and `references/rebuild.md`.

## Reference files

- `references/detection.md` — how to read stack + existing workflows + version state + branch model
- `references/ci-structure.md` — per-stack lint + typecheck + format:check + build jobs; extend-vs-create logic
- `references/ci-cost-migration.md` — retrofit an existing repo to the deduplicated `push` triggers (non-breaking); notes on the separate, breaking job-consolidation change
- `references/ci-cost-verification.md` — prove a cost change worked using GitHub's own billed minutes (`runs/{id}/timing`): before/after tables, pricing constants, and the gotchas (a `0` billable reading is not "free")
- `references/release-please.md` — workflow, config, manifest; monorepo variant; tag-pattern gotchas
- `references/release-verification.md` — `verify-tag` (folded into `release-please.yml`) + `release-health.yml` + `discord-alert` composite: fail-loud + Discord alert when a merged release PR produces no tag; optional `DISCORD_GH_ERRORS_WEBHOOK` secret
- `references/develop-to-main-pr.md` — `develop-to-main-pr.yml`: auto-opens/refreshes the draft `develop → main` release PR (gitflow without staging)
- `references/rebuild.md` — `rebuild.yml`: `/rebuild` PR-comment re-runs failed CI (gitflow); pairs with the PAT setup
- `references/deploy-stub.md` — `deploy.yml` with the deploy-target picker, secret-setup guidance, and platform examples (Render, Vercel, Fly, Railway, GHCR, SSH/rsync)

## Why these defaults

- **Deploy stub is platform-neutral.** All targets are commented snippets with the same structure — none is wired in by default, since each requires user-supplied credentials and decisions. The stub includes a "How to use this file" header that walks the user through picking a target, fetching credentials, and adding secrets to GitHub Environments.
- **release-please over manual versioning** — drives off conventional commits, opens PRs you review, no manual tag/changelog work.
- **No build job for Python** — Python apps generally deploy source via container or buildpack; a separate `build` step adds CI time without value. Library projects can opt in by extending the workflow.
- **Idempotent on re-run** — skips files that exist, extends `ci.yml` jobs without duplicating, surfaces what was skipped.
- **Composes cleanly with `testing-init`** — neither skill stomps on the other's CI jobs. Run order doesn't matter.
