# Git workflow rule template (scaffolded into each new project)

This file is the **template content** that `project-scaffold` Step 10 writes to `.claude/rules/git-workflow.md` in the new project. It captures the workflow conventions the rest of the scaffold (protected branches, release-please, deploy on tag, etc.) assumes.

Write it verbatim. Replace `<PROJECT_NAME>` with the project name only if the template uses it (it currently doesn't).

The "Release flow" and "Reverting a release" sections describe the **tagged-only deploy** model — canonical explanation in `gh-actions-init/references/tagged-deploy.md`. A brand-new project has no hosting service yet, so the scaffold gates deploys off with the `RENDER_DEPLOY=false` repo variable: the release chain (promote → release PR → auto-merge → tag) works fully, and only the deploy step is dormant. Keep both sections, and in step 5 note that deploys are currently gated off rather than promising a deploy that can't happen — then drop the qualifier at go-live.

---

## Template content

````markdown
# Git workflow

Conventions for this repo, intended for both humans and Claude sessions. The CI/CD pipeline, branch protection, and release flow all assume these rules — bypassing them risks accidental production deploys.

## Always work in an isolated branch

Never edit files directly on `develop` or `main`. Always create a feature branch first.

**Automated / AI agent sessions (e.g. Claude): always work in a git worktree — no exceptions.** Don't edit files in the primary checkout, even on a feature branch. Working in the primary checkout pollutes the user's branch list and causes working-directory-reset confusion across tool calls. Create an isolated worktree as the first action of any code task; if you catch yourself committing in the primary checkout, stop and move the work to a worktree.

Run `git branch --show-current` before every commit. If the result is `develop` or `main`, **stop** — uncommit nothing, but move the changes to a feature branch before committing.

## Branching

- Branch off `origin/develop`, never `main`. (Only branch off `main` for hotfixes against a tagged release.)
- If you're using git worktrees, the worktree branch must also be based on `origin/develop`. Either create it from `origin/develop` directly, or run `git fetch origin develop && git rebase origin/develop` after entering the worktree.

## Branch naming

- Feature work: `feature/<short-kebab-name>` on the remote.
- Bug fixes: `fix/<short-kebab-name>`.
- Chores / refactors / docs / CI: `chore/<short-kebab-name>`.
- Releases (release-please opens these for you): `release-please--…`.
- Auto-promotion (the workflow opens these for you): `chore/promote-develop-to-main`.

If you use a personal local prefix (e.g., `worktree/<name>` for branches in a worktree), keep it different from the remote prefix so a worktree branch and its remote counterpart don't collide. See "Pushing" below for the refspec pattern.

## Pushing

- **Never push directly to `develop` or `main`.** Never force-push them under any circumstances.
- Always use an explicit refspec — don't push `HEAD`. The pattern is:
  ```bash
  git push -u origin <local-branch>:<remote-branch>
  ```
  Example: `git push -u origin worktree/dark-mode:feature/dark-mode`
- After the initial push, follow-up pushes from the same local branch go to the same remote branch automatically.

**Push gotcha:** `git checkout -b feature/x origin/develop` sets the new branch's upstream to `origin/develop`. A naive `git push -u origin feature/x` then pushes TO `develop`. Always use the explicit `local:remote` mapping to avoid this.

**Tag push gotcha:** Some setups have pre-push hooks that flag any push whose upstream tracks `main`/`develop` as a protected-branch push. To push a tag past such a hook, use the explicit tag refspec:
```bash
git push origin refs/tags/<tagname>:refs/tags/<tagname>
```

## Force-push exception: rebasing a stacked PR after its parent squash-merges

When PR A has been **squash-merged** into `develop` and PR B was originally branched off PR A's branch, PR B's history still contains PR A's pre-squash commits. Squash-merging PR B in that state risks GitHub computing a confusing diff. The fix is to rebase PR B onto `develop` and force-push.

**This specific force-push is allowed**:
1. Confirm PR A is squash-merged.
2. In PR B's branch / worktree: `git fetch origin develop && git reset --hard origin/develop`
3. `git cherry-pick <PR-B's-original-feature-commit>` — resolve any small conflicts to keep only PR B's additions.
4. `git push --force-with-lease origin <local>:<remote>`

Always `--force-with-lease`, never plain `--force`. Never force-push to `main`/`develop` regardless.

## Pull requests

- Open PRs against `develop` (the default branch). The PR can be **draft** until you want review.
- **Before opening, audit the diff:** run `git diff --stat origin/develop...HEAD` and confirm every changed file is intentional. Machine-local state (`.claude/settings.local.json`, `.env.local`) and scratch files get staged by accident — strip them rather than explaining them in the PR body.
- Let CI gate merges. The consolidated pipeline (`checks` = lint + format:check + typecheck + unit; plus e2e and build) must be green.
- PR title should follow conventional-commit format (`feat:`, `fix:`, `chore:`, etc.) — release-please uses commit / PR titles to compute version bumps.
- PR body should include a "Summary" and a "Test plan" (checkbox list of how to verify the change).

## Commit-message hygiene

**Don't write `BREAKING CHANGE:` or `feat!:` in commit-body prose unless you actually mean them.** Conventional-commits parsers (release-please included) match these patterns liberally and will treat text after the marker as a breaking-change description — even inside backticks, even when you're only *referring* to the markers in narrative. The result is a bogus `⚠ BREAKING CHANGES` section in the generated CHANGELOG. If you need to reference them, paraphrase: "the breaking-change footer", "the bang-suffix on `feat`".

## Release flow (driven by release-please)

1. Feature branches merge into `develop` via PR.
2. When ready to release: open a PR `develop` → `main` (the auto-promotion workflow opens it for you). CI runs the same checks.
3. Merging `develop` → `main` triggers `release-please.yml`, which opens (or updates) a release PR against `main` with a generated `CHANGELOG.md` and version bump. **Every promotion produces a release**, via two settings in `release-please-config.json`:
   - **Path:** the package is scoped to the repo **root** (`"."`), never an app subdirectory. release-please only counts commits under a package's path, so a subdirectory scope makes a change to an internal workspace package or to root tooling cut *no* release — and therefore never deploy, leaving live code dead in production. The root `package.json` holds the version; `extra-files` mirrors it into the app's.
   - **Type:** `changelog-sections` un-hides all commit types, so even a docs/ci/chore-only promotion has a non-empty changelog and isn't skipped. Versioning stays semantic: `feat` → minor, breaking → major, everything else → at least a patch.
4. That same run **auto-merges the release PR** (squash, with the release PAT) — you don't touch it. Merging the promotion PR in step 3 is the *only* human gate. **Pause switch:** set the repo variable `RELEASE_AUTOMERGE=false` to keep the release PR open for manual review; merging it yourself still tags and deploys. Unset it to resume hands-off releases.
5. The release-PR merge fires a second `release-please.yml` run that tags the commit (e.g., `v1.2.0`), creates the GitHub Release, and **deploys production** — the deploy step runs in that same job and targets the tagged commit. The host's branch auto-deploy is **off**, so this is the only thing that ships prod: production always runs the exact tagged commit, the untagged promotion merge never deploys, and a release never deploys twice.

**Release-PR merges — edit the PR *title*, not just the squash-commit title.** release-please reads the **PR title** field (not the merge-commit message) to extract the version on merge. If you need to fix a release PR's title, edit it via the pencil icon on the PR page before merging. Editing only the squash-merge commit title in the merge dialog leaves the PR title wrong, and the auto-tag step silently fails (it parses the wrong text as the version and creates no tag).

## Reverting a release

**Roll _forward_, don't roll back.**

- **Don't redeploy an older tag** if this app runs migrations on deploy — the schema has already migrated forward, and the old code was never tested against it. Redeploying an old tag is a last resort, safe only when you're certain the released migrations are backward-compatible with the older code.
- **Don't `git revert` the tagged commit.** With release-please the tagged commit's own diff is only `CHANGELOG.md` + the version bump; the release's actual code landed one commit earlier, in the `develop → main` promotion merge. Reverting the tag backs out the changelog, not the bug.
- **Do revert the offending feature commit(s).** On a `fix/…` branch off `develop`, `git revert` the PR that introduced the bug — or `git revert -m 1 <the promotion-merge commit>` to back out the whole release. PR into `develop` → promote → it ships as the next patch through the normal flow.
- **Fix a bad migration forward** with a new corrective migration. Never write a down-migration to un-apply a released one.

## Why these rules

`develop` is the protected integration branch — every change has to pass through CI before landing. `main` only gets the auto-promotion PR and release-please's release PRs. Pushing directly to either bypasses CI and can produce accidental deploys. The branch-protection rules in this repo enforce most of this, but the local conventions catch issues before you push.

**Tagged-only deploys:** because the host's auto-deploy is off, a push to `main` never deploys by itself. Only `release-please.yml`, after it verifies a `vX.Y.Z` tag exists on the remote, triggers the production deploy against that tag's commit. This is why the promotion merge (untagged feature code) doesn't ship to prod, and why each release deploys exactly once. Requires the deploy-hook secret in the repo and auto-deploy disabled on the hosting service.
````

---

## How this is used

`project-scaffold` Step 10 copies the **template content** (everything between the outer `````markdown` fences) verbatim to `<project-root>/.claude/rules/git-workflow.md` in the new project.

The CLAUDE.md template (in `claude-md-init`) references this file with `@.claude/rules/git-workflow.md`, so any Claude session working in the project picks it up automatically.

For retrofitting an existing repo with these rules: run `cp` of the template content directly, no skill needed — though `claude-md-init` could optionally do it if invoked with `--with-workflow-rule`.
