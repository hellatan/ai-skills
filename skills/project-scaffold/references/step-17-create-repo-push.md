# Step 17 — Create GitHub repo + bootstrap push

Creates the remote on GitHub, sets it as `origin`, and pushes the initial scaffold to `main`, `develop`, and (if opted in) `stage`.

The remote creation and push are bracketed by explicit action gates. Do not
continue from a text-only note: use the active harness's observed approval
mechanism and wait for the required user authorization.

## Step 17a — PRE-PUSH GATE (halt for user action)

Print this message and wait for the active harness's required approval before
continuing. Do not auto-continue on silence.

> ⚠️ **Remote bootstrap coming up** — this creates `<owner>/<name>` and seeds
> `main` and `develop`. After this, every change goes through normal PRs.
>
> Step 16 inspected: `<sources and observed constraints>`. Remaining unknowns
> include host and harness policy. I will use the active approval flow and will
> not disable or override a protection.
>
> Approve creating this remote and running the listed bootstrap pushes.

If the user replies anything other than affirmative confirmation, stop and surface why they're hesitant — don't push.

## Step 17b — Push

```bash
gh repo create <name> --private --source=. --remote=origin

# Allow GitHub Actions to create + approve PRs on this repo.
# Default for new repos is OFF, which makes the first workflow run that calls
# `gh pr create` (or uses an action that creates PRs internally, like
# googleapis/release-please-action) fail with:
#   pull request create failed: GraphQL: GitHub Actions is not permitted to
#   create or approve pull requests (createPullRequest)
gh api repos/<owner>/<name>/actions/permissions/workflow --method PUT \
  --field default_workflow_permissions=write \
  --field can_approve_pull_request_reviews=true

# Bootstrap pushes use explicit source:destination refspecs. After this, all
# changes go through PRs.
git push -u origin main:main
git push -u origin develop:develop
```

If staging was opted in:

```bash
git push -u origin stage:stage
```

If user picked **Public** in Step 7, replace `--private` with `--public`.

### Why the workflow-permissions API call

`release-please.yml` (scaffolded in Step 14) and any workflow that uses `GITHUB_TOKEN` to create PRs — auto-promote, label-driven backports, dependency bumps, anything that calls `gh pr create` from CI — needs the repo-level setting **"Allow GitHub Actions to create and approve pull requests"** to be on. GitHub's default for new repos is **off**, so without this call the very first PR-creating workflow run fails with `GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)`. For release-please specifically, the error doesn't surface until the first non-`chore:` commit lands on `main` (chore-only history produces no version-bump PR), so the failure can sit dormant for weeks before biting.

The flag names (`default_workflow_permissions=write`, `can_approve_pull_request_reviews=true`) are exact — both are required and both are easy to typo. Doing this immediately after `gh repo create`, before the first push, means the setting is in place before any workflow ever runs.

### The `RELEASE_PLEASE_TOKEN` secret (user action — every new repo needs this)

`release-please.yml` and `develop-to-main-pr.yml` (scaffolded in Step 14 via `gh-actions-init`) author their PRs with the `RELEASE_PLEASE_TOKEN` repo secret instead of `GITHUB_TOKEN` — bot-authored PRs park their CI behind a manual "Approve and run" gate (`action_required`) and never trigger it in the first place, so without the secret those workflows fail with an auth error and no release ever goes green on its own.

This is a **blocking chat callout right after the repo is created** — surface it in Step 17b's output, not just the final report. The secret value is the user's PAT, so the user runs it themselves (the command prompts for the value — don't ask them to paste the PAT into chat):

> 🔑 **Action needed: `RELEASE_PLEASE_TOKEN` secret.** The release workflows authenticate with a fine-grained PAT (Contents: read/write + Pull requests: read/write). Two steps:
>
> 1. Make sure this new repo is in the PAT's repository-access list (GitHub → Settings → Developer settings → Fine-grained tokens) — repo-scoped PATs don't cover repos created after them.
> 2. Run: `gh secret set RELEASE_PLEASE_TOKEN --repo <owner>/<name>` (paste the PAT when prompted).
>
> Until this is done, release-please and the develop→main auto-PR fail on their first run.

Don't block the push on it (the workflows only matter once commits land), but re-surface it in the Step 21 report if the user hasn't confirmed it. Verify with `gh secret list --repo <owner>/<name>`.

### The `CLAUDE_CODE_OAUTH_TOKEN` secret (user action — every new repo needs this)

`claude-code-review.yml` (scaffolded in Step 14 via `gh-actions-init`) authenticates the Claude action with this repo secret. It is **per repo** — there is no org-level fallback, and a token minted before this repo exists still covers it (unlike the fine-grained PAT above). Without it the review job still triggers and then fails on its action step: a red X on every PR that reads like a CI failure rather than a missing review.

Not blocking — nothing else depends on this workflow — but list it beside `RELEASE_PLEASE_TOKEN` in the same callout so both are one trip:

> 🔑 **Also: `CLAUDE_CODE_OAUTH_TOKEN`.** Mint one with `claude setup-token` (requires a Claude subscription), then `gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<name>`. Until then, `claude-code-review` shows a failing check on every PR.

### Release/deploy repo variables (set these — no user action needed)

The scaffolded `release-please.yml` reads two repo **variables** (not secrets, so Claude can set them directly). A brand-new repo has to start in the right state:

```bash
# No hosting service exists yet, so there's no deploy hook to configure. Without
# this gate the repo's FIRST tagged release would fail the release workflow —
# on a project that was never deployed. With it, the whole release chain works
# (promote → release PR → auto-merge → tag) and only the deploy step is dormant.
gh variable set RENDER_DEPLOY --body false --repo <owner>/<name>

# Only when Step 6 opted into staging — unset reads as ENABLED, so skipping this
# makes the first pre-release tag off `stage` fail on the missing staging hook.
gh variable set RENDER_STAGE_DEPLOY --body false --repo <owner>/<name>

# RELEASE_AUTOMERGE is deliberately left UNSET — unset means auto-merge is ON,
# which is the intended default. Only set it to `false` to pause hands-off
# releases for manual review.
```

Both are documented in `gh-actions-init/references/tagged-deploy.md`. Surface the **go-live checklist** in the Step 21 report so the user knows how to switch deploys on later: create the service from the committed deploy config (it already carries `autoDeploy: false`, so a *fresh* service starts with auto-deploy off — nothing to flip), add the deploy-hook secret, then delete the `RENDER_DEPLOY` variable. The next release deploys automatically.

## Step 17c — POST-PUSH GATE

Report the completed remote action before continuing to Step 18. If the active
harness requires another approval for the next action, request it then.

> ✅ **Bootstrap push done.** `main` and `develop` are seeded on the remote.
>
> All subsequent operations (branch protection, default-branch swap, smoke test, future PRs) honor the workflow rules normally — no more direct pushes to protected branches from this skill.
>
> Subsequent operations (branch protection, default-branch swap, smoke test,
> and future PRs) use their normal authorization and branch-protection flows.

## The bootstrap exception (read carefully)

This is the **only** point at which `project-scaffold` pushes directly to protected branches. It exists because there's no way to seed `main` and `develop` on a brand-new remote without a direct push (PRs require a target branch to already exist).

**The exception is push-only and scoped to seeding the remote.** After Step 17 completes:

- All changes (including dep installs, fixups, follow-up commits) go through the standard PR → `develop` flow.
- Branch protection bypass is **never** authorized for merging PRs.
- The skill must not extend the bootstrap exception to any subsequent operation, even if a follow-up step "would be easier" with a direct push. Use a feature branch + PR instead.

## Why each push is its own command

Pushing all branches in one command (e.g., `git push -u origin main develop stage`) seems cleaner but obscures which branch failed if the override env var is wrong. Three separate commands surface failures cleanly and let the user/skill recover from a partial state.
