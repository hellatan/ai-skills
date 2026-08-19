---
name: gitflow-init
description: Set up the main + develop (+ optional stage) branch model on an existing repo, push the new branches, apply branch protection, switch the GitHub default branch to develop, and write a CONTRIBUTING.md documenting the branch/PR/commit conventions. Use when the user wants to "set up gitflow", "add a develop branch", "configure branch protection", "add a CONTRIBUTING.md", "document our branching/PR conventions", "set up a PR-flow workflow", or otherwise bring this project's git workflow conventions to a repo that doesn't have them yet. Detects current branch state, idempotent — won't recreate branches that exist or stomp on existing protection rules without consent.
---

# gitflow-init

Brings this project's git-flow conventions to an existing repo: `main` + `develop` (+ optional `stage`), branch protection, and `develop` as the default branch on GitHub. Composable with `project-scaffold` (called internally for new projects' Steps 18 + 19).

## When to trigger

User says any of:
- "set up gitflow / git-flow on this repo"
- "add a develop branch"
- "configure branch protection"
- "set up a PR-flow workflow"
- "make develop the default branch"

## When NOT to use

- Repo already has `main` + `develop` working with branch protection — extend manually if needed.
- Brand-new project — use `project-scaffold` (which calls this skill internally for Steps 18 + 19).
- User wants Trunk-based or feature-flag-only workflow — this skill is opinionated about main + develop.

## What this skill does NOT touch

- **Initial commit / `git init`** — assumes the repo already has commits on `main` (or whatever the default branch is).
- **Tests, CI, release-please, deploy** — separate skills (`testing-init`, `gh-actions-init`).
- **Pre-commit hooks** — separate skill (`precommit-init`).

---

## Flow

### 1. Detect current state

Read these without asking:

```bash
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
has_develop=$(git ls-remote --heads origin develop | grep -q . && echo true || echo false)
has_stage=$(git ls-remote --heads origin stage | grep -q . && echo true || echo false)

# Branch-protection availability (matters on private repos: requires GitHub Pro).
# Do NOT use `gh api user --jq .plan.name` — it needs the `user` token scope, which
# the standard gh login (`gist, read:org, repo, workflow`) lacks, so it silently
# returns null and tells you nothing. Probe the capability itself instead: a GET
# on the protection endpoint is side-effect-free (never use PUT to probe — on paid
# plans it would APPLY protection) and discriminates by error:
#   403 "Upgrade to GitHub Pro"  -> free tier + private: protection unavailable
#   404 "Branch not protected"   -> protection available, none applied yet
#   200                          -> protection available and already applied
protection_probe=$(gh api "repos/{owner}/{repo}/branches/${default_branch}/protection" 2>&1) && protection=applied || {
  case "$protection_probe" in
    *"Upgrade to GitHub Pro"*) protection=unavailable ;;
    *"Branch not protected"*)  protection=available ;;
    *)                         protection="unknown ($protection_probe)" ;;
  esac
}
gh repo view --json visibility -q .visibility
```

Surface findings: *"Detected: default branch `main`, no `develop`, no `stage`, repo is private and the protection probe returned 403 (free tier) — branch protection won't apply, skipping it."*

### 2. Pick scope

Three independent decisions:

**a. Create `develop`?** Default yes if it doesn't exist. The whole skill's premise is that work flows through `develop`.

**b. Create `stage`?** Default no. Ask:

> Want a `stage` branch as a pre-production rehearsal? Code goes there before `main`, deploys to a staging environment, gives you a click-around safety net before real users see it. If you're solo or just starting out, you can skip this and add it later.

**The branch is the gate on the whole staging environment.** No `stage` branch → no staging deploy target, and that is the intended end state for most repos, not a gap. If `stage` *is* created, the staging environment deploys from **pre-release tags** (`vX.Y.Z-rc.N`) cut off it — never from a push to `stage`, and never from a platform auto-deploy watching a branch. This skill only creates the branch; the workflows and config that make it deploy live in `gh-actions-init` — see the "Environments" section of `gh-actions-init/references/tagged-deploy.md`. Mention that in the summary so the user knows the branch alone doesn't ship anything.

**c. Apply branch protection?** Default yes — but skip silently if Step 1 detected free-tier + private (see Step 6 fallback).

### 3. Show summary, halt for confirmation

Render the plan as a code block with emoji headers (same convention as `project-scaffold` Step 8):

```
🔍 Detected:           <default branch> + <existing branches>
🌿 Branches to create: <develop | develop + stage | none if already there>
🔒 Branch protection:  <will apply to main + develop (+ stage) | skipping (free tier + private)>
🐙 Default branch:     <set to develop | already develop>
```

End with: *"Reply 'yes' / 'go' / 'looks good' to proceed, or tell me what to change."*

### 4. **HALT for confirmation**

Same gate as `project-scaffold`. Wait for explicit affirmative reply.

---

## Execution

### 5. Create + push branches that don't exist

```bash
# Only run for branches that don't exist yet (per Step 1 detection)
git fetch origin
git branch develop origin/$default_branch  # base develop off the current default
git push -u origin develop

# If staging opted in:
git branch stage origin/$default_branch
git push -u origin stage
```

If the user has a global pre-push hook that blocks pushing new branches (uncommon, but possible — see `project-scaffold/references/step-16-prepush-hooks.md`), surface and ask before retrying with the override env var.

### 6. Apply branch protection

See `references/branch-protection.md` for the `gh api` script and the 403 fallback message. Apply to `main`, `develop`, and (if created) `stage`.

### 7. Set `develop` as default branch

```bash
gh repo edit --default-branch develop
```

PRs default to merging into `develop`. `main` only gets touched by release flows.

### 8. Write `CONTRIBUTING.md`

The human-facing counterpart to `CLAUDE.md`, documenting the branch model this skill just
applied. Default-on; skip if the file already exists (offer to extend it instead). Template
and placement rules: `references/contributing-md.md`.

Note there is **no org-wide default for user accounts** — a `.github` org repo can supply
one, but only for organizations. Personal-account repos each need their own file, which is
why this is scaffolded rather than hand-copied.

### 9. Report back

Print:
- ✅ What was created (branches)
- ✅ What was protected (or skipped with reason)
- ✅ Default branch state
- ✅ `CONTRIBUTING.md` written (or skipped — already present)
- 📋 Next steps:

```
Next steps:
1. Open new feature branches off `develop`, not `main`
2. PRs target `develop`. Releases: merge `develop` → `main` (release-please opens the release PR)
3. (If you don't have CI yet) Run `/gh-actions-init` to add the workflows that branch protection will require
```

---

## Reference files

- `references/branch-protection.md` — `gh api` protection script + 403 fallback message
- `references/contributing-md.md` — `CONTRIBUTING.md` template, placement, and why user
  accounts get no org-wide default

## Why these defaults

- **`develop` as default branch** — PRs land in `develop` first; `main` stays release-only. release-please opens its release PR from `develop` → `main`. `main` getting touched only on release means the deploy workflow tied to `v*.*.*` tags is unambiguously the production trigger.
- **`stage` is opt-in** — most projects don't need it day one; adding it later is a one-command operation. Its absence is also the absence of a staging *environment*, deliberately: `gh-actions-init` scaffolds a staging deploy only when the branch exists (`gh-actions-init/references/tagged-deploy.md`, "Environments").
- **Skip protection on free-tier private** — branch protection requires GitHub Pro for private repos. The skill scaffolds the rest of the workflow and surfaces the limitation rather than failing the whole flow.
- **Composes with `project-scaffold`** — its Steps 18 + 19 point directly at `references/branch-protection.md` and the `gh repo edit --default-branch develop` command. Run order doesn't matter (project-scaffold wraps gitflow-init's logic; gitflow-init standalone is for retrofits).
