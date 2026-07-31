# Tagged-only deploy

The deploy model this skill scaffolds by default, and the canonical explanation of *why*. Other reference files cross-link here rather than restating it.

**The invariant:** one human gate — merging the `develop → main` promotion PR — then everything is automatic: release PR → tag → deploy of **the exact tagged commit, exactly once**. `main` and production stay in lockstep. Nothing untagged ever ships; nothing tagged ever fails to ship.

Verified end-to-end on a production Next.js app deployed to Render. The Render pieces below are the tested path; the other platform blocks are documented-but-unverified and clearly marked as such.

---

## The problem it solves

release-please pushes to the release branch **twice per release**:

1. The `develop → main` **promotion merge** — this is the push that carries the real feature code. It is **untagged**.
2. The **release-PR merge** — a commit whose own diff is only `CHANGELOG.md` + the version bump. *This* is the commit that gets tagged.

Any platform configured to auto-deploy a branch (Render, Vercel, Netlify, Cloudflare Pages, Fly's GitHub integration, …) therefore ships **twice per release**, and the deploy that first put the new code in front of users was the **untagged** one. "What version is in production?" has no answer, and rolling back has no anchor.

The fix is the same shape everywhere: **turn off the platform's native git auto-deploy and drive the deploy from CI, gated on a tag having been cut.** Render has no native tag trigger — its auto-deploy only ever watches a branch — so CI is the only place this can be decided.

---

## The five parts

### 1. Platform auto-deploy off

Render: `autoDeploy: false` in `render.yaml`.

> ⚠️ `render.yaml` alone is not enough. `autoDeploy: false` only takes effect once the Blueprint is re-synced in the dashboard. Flip auto-deploy off on the service in the dashboard too, or the platform keeps deploying every push to `main` and the whole model is silently inert. Same class of step on every other platform — the setting lives in the platform, the file only declares it.

### 2. A deploy step inside `release-please.yml`, gated on a verified tag

Not a separate `deploy.yml` on `on: push: tags` — see the loop-guard gotcha below. The step runs in the **same job** that cut the tag and keys off the `released` output from the `verify-tag` steps (`references/release-verification.md`), which is `true` only when a tag was cut **and** the ref was confirmed on the remote.

`github.sha` on that run **is** the commit release-please just tagged, so passing it as the deploy ref guarantees the platform builds the tagged commit and never the untagged promotion merge.

### 3. Auto-merge the release PR

So a release is hands-off after the single human gate. Two load-bearing details, both of which silently break the chain if got wrong — see the step below.

### 4. release-please scoped to the repo **root** (`"."`), not a subdirectory

**The biggest landmine in this whole design.** release-please only counts commits that touch files **under a package's path**. Scoped to `apps/web`, a change confined to an internal workspace package (bundled into the app at build time) or to root-level tooling cuts **no release** — so it never tags, and with tagged-only deploys it therefore **never deploys**. Real runtime code sits on `main`, present in the repo and dead in production, with nothing failing.

Root-scoping makes any file anywhere count. The **root** `package.json` holds the version; `extra-files` mirrors it into the deployed app's `package.json`; internal packages stay `private` and unversioned. Config in `references/release-please.md`.

Chosen over release-please's `node-workspace` plugin, which versions private packages and risks a second tag stream.

### 5. `changelog-sections` un-hiding **all** commit types

release-please **skips the release entirely when the changelog would be empty**, and `chore` / `docs` / `ci` / `style` / `test` / `build` are hidden by default. So a docs-only or CI-only promotion cuts no tag and never deploys — `main` drifts ahead of production again, by exactly the changes nobody thought were risky.

Un-hiding every type means every promotion produces a release. Versioning stays semantic: **do not** reach for `always-bump-patch`, which flattens `feat` → patch. The default strategy already floors everything at a patch while keeping `feat` → minor and breaking → major.

Tradeoff, stated plainly: a docs-only promotion also triggers a build + deploy — a near-no-op rebuild. That is the price of a strict `main == production` invariant.

---

## ⚠️ Universal gotcha: a `GITHUB_TOKEN`-pushed tag does **not** fire `on: push: tags`

GitHub's recursion guard suppresses workflow triggers for any ref pushed with the built-in `GITHUB_TOKEN`. A `deploy.yml` listening on `on: push: tags: ['v*.*.*']` will therefore **never run** for a tag that release-please cut with `GITHUB_TOKEN` — a deploy pipeline that looks correct, passes review, and simply never executes.

Two ways out:

- **Fold the deploy into the same job that cuts the tag** — what this design does. No cross-workflow trigger to suppress. Also the only option on platforms whose deploy is a single API call.
- **Push the tag with a PAT** (`RELEASE_PLEASE_TOKEN`), which restores the trigger. Needed when the deploy genuinely must be its own workflow (matrix builds, a separate `environment:` approval gate, per-component fan-out).

The same guard is why the auto-merge step below must use the PAT.

---

## The deploy step — Render (verified)

Appended to the `release-please` job in `.github/workflows/release-please.yml`, after the `verify-tag` steps:

```yaml
# Production deploy — the ONLY thing that ships prod (render.yaml has
# autoDeploy: false). Fires only when this run cut a VERIFIED tag, and deploys
# github.sha, which IS the commit release-please just tagged (the release PR's
# merge commit). So the platform always builds the exact tagged version, never
# the untagged promotion-merge commit.
- name: Deploy tagged release
  if: ${{ steps.check.outputs.released == 'true' }}
  env:
    RENDER_DEPLOY_HOOK_URL: ${{ secrets.RENDER_DEPLOY_HOOK_URL }}
    SHA: ${{ github.sha }}
  run: |
    if [ -z "$RENDER_DEPLOY_HOOK_URL" ]; then
      echo "::error::RENDER_DEPLOY_HOOK_URL secret is unset — a release was tagged but production cannot be deployed. Add the deploy hook URL (dashboard → service → Settings → Deploy Hook) as a repo secret."
      exit 1
    fi
    echo "Triggering deploy of tagged commit ${SHA}"
    # The hook URL already carries ?key=…, so ref is appended with &.
    http_code=$(curl -sS -o /tmp/deploy-response.json -w '%{http_code}' \
      -X POST "${RENDER_DEPLOY_HOOK_URL}&ref=${SHA}")
    echo "Deploy hook returned HTTP ${http_code}"
    cat /tmp/deploy-response.json 2>/dev/null || true
    echo ""
    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
      echo "::error::Deploy hook failed (HTTP ${http_code}) for tagged commit ${SHA}."
      exit 1
    fi
    echo "Deploy queued for ${SHA}."
```

**Fail loudly on a missing secret.** The alternative — skipping the step when `RENDER_DEPLOY_HOOK_URL` is unset — produces a green release that shipped nothing, which is the exact failure class this whole design exists to eliminate.

Required repo secret: **`RENDER_DEPLOY_HOOK_URL`** (dashboard → service → Settings → Deploy Hook). Surface it as a blocking setup step in the report, alongside `RELEASE_PLEASE_TOKEN`.

---

## The auto-merge step

```yaml
# Auto-merge the release PR so a release is hands-off after the one human gate
# (merging the develop→main promotion PR). On a promotion run, release-please
# opens the "chore: release X.Y.Z" PR above; this squash-merges it, which pushes
# to main and fires a SECOND release-please.yml run that cuts the tag and
# deploys (the step above).
#
# Two load-bearing details:
#  1. Merge with the PAT, not GITHUB_TOKEN. A GITHUB_TOKEN-authored merge push
#     does NOT re-trigger workflows (the recursion guard), so the tag+deploy run
#     would never happen and the release would freeze silently.
#  2. Find the PR by its `autorelease: pending` LABEL, not the action's `pr`
#     output — release-please namespaces per-package outputs as `<path>--<key>`,
#     so the bare output is empty for any non-root package (same trap as the tag
#     check in references/release-verification.md).
#
# Skipped on the tag-cutting run (released == 'true') and when release-please
# itself failed, so a stale release PR is never merged.
#
# PAUSE SWITCH: set the repo variable RELEASE_AUTOMERGE=false to keep the
# release PR OPEN for manual review — e.g. to eyeball a version bump after a
# release-please config change before it tags + deploys. Unset (or anything but
# 'false') = auto-merge on. This gates ONLY the automatic merge; when you merge
# the PR yourself, the tag + deploy still fire.
- name: Auto-merge the release PR
  if: ${{ steps.release.outcome == 'success' && steps.check.outputs.released != 'true' && vars.RELEASE_AUTOMERGE != 'false' }}
  env:
    GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
  run: |
    pr=""
    for attempt in 1 2 3; do
      pr=$(gh pr list --base main --state open \
        --label "autorelease: pending" --json number --jq '.[0].number // empty')
      if [ -n "$pr" ]; then break; fi
      echo "No pending release PR yet (attempt ${attempt}/3), retrying in 5s..."
      sleep 5
    done
    if [ -z "$pr" ]; then
      echo "No pending release PR to auto-merge this run."
      exit 0
    fi
    echo "Auto-merging release PR #${pr} with the release PAT"
    gh pr merge "$pr" --squash --delete-branch
```

**Do not scaffold auto-merge without the `verify-tag` steps.** Auto-merge removes "a human happened to be watching" as the only guard that a release actually tagged; the verification steps are what replace it. Scaffold them together, always.

`RELEASE_AUTOMERGE` is a repo **variable**, not a secret: `gh variable set RELEASE_AUTOMERGE --body false --repo <owner>/<repo>` to pause, `gh variable delete RELEASE_AUTOMERGE --repo <owner>/<repo>` to resume.

---

## Other platforms — same shape, different mechanism (⚠️ NOT verified)

> **Read this before using anything in this section.** Only the Render path above has been run in production. The blocks below are derived from each platform's documentation and have **not** been verified in practice. Scaffold them **commented out**, keep the Render block as the active default, and walk the "verify on your first deploy" checklist before trusting one.

The invariant transfers unchanged — disable the platform's native git auto-deploy, deploy from CI once a tag is verified. What differs is *how you point the deploy at a specific commit.*

### Vercel / Netlify / Cloudflare Pages

Same branch-auto-deploy problem, same fix shape, **one important difference**: Vercel deploy hooks **cannot target a ref** — a hook always builds the branch tip, which defeats the entire point. So instead of POSTing a hook, check out the tagged commit and run the platform CLI from CI.

```yaml
# ⚠️ UNVERIFIED — derived from Vercel's docs, not run in production. Verify with
# the checklist below before relying on it.
#
# Prerequisite in the Vercel dashboard: Settings → Git → disable automatic
# deployments for the production branch (the equivalent of autoDeploy: false).
#
# - name: Deploy tagged release to Vercel
#   if: ${{ steps.check.outputs.released == 'true' }}
#   env:
#     VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
#     VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
#     VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
#   run: |
#     if [ -z "$VERCEL_TOKEN" ]; then
#       echo "::error::VERCEL_TOKEN is unset — a release was tagged but production cannot be deployed."
#       exit 1
#     fi
#     # github.sha is already checked out by actions/checkout in this job, and IS
#     # the tagged commit — the build below is of the tagged tree.
#     npx vercel pull --yes --environment=production --token="$VERCEL_TOKEN"
#     npx vercel build --prod --token="$VERCEL_TOKEN"
#     npx vercel deploy --prebuilt --prod --token="$VERCEL_TOKEN"
```

Netlify (`netlify deploy --prod --dir=...` with `NETLIFY_AUTH_TOKEN` + `NETLIFY_SITE_ID`) and Cloudflare Pages (`wrangler pages deploy` with `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`) follow the same build-then-upload pattern — likewise unverified.

### Generic CI-driven targets (raw AWS: Lambda / ECS / S3+CloudFront, self-managed servers)

These are usually **already** CI-driven — there is no native git auto-deploy to disable, so part 1 is a no-op. All that's needed is to gate the existing deploy job on the tag.

```yaml
# ⚠️ UNVERIFIED as part of this release flow — the deploy commands themselves are
# ordinary AWS CLI calls, but the tag gating below hasn't been run in production.
#
# - name: Deploy tagged release
#   if: ${{ steps.check.outputs.released == 'true' }}
#   env:
#     AWS_REGION: us-east-1
#   run: |
#     # Credentials via OIDC (aws-actions/configure-aws-credentials) — preferred
#     # over long-lived keys. The checked-out tree IS the tagged commit.
#     # e.g. aws s3 sync ./out s3://$BUCKET --delete
#     #      aws cloudfront create-invalidation --distribution-id "$DIST" --paths '/*'
#     #      aws ecs update-service --cluster "$CLUSTER" --service "$SVC" --force-new-deployment
```

If the deploy genuinely has to live in its own workflow (matrix, `environment:` approval gate), remember the loop guard: the tag must be pushed with a PAT for `on: push: tags` to fire at all.

### Verify on your first deploy — checklist

Run this once, on the first real release after wiring up a non-Render platform:

1. **Auto-deploy is actually off.** Push a trivial commit to `main` without a release. Nothing should deploy. (Catches the "the file says off, the dashboard says on" trap.)
2. **The tagged commit is what shipped.** Compare the deployed build's commit SHA (most platforms show it in the deployment detail) against the `vX.Y.Z` tag. They must be identical — not the promotion merge one commit earlier.
3. **Exactly one deploy per release.** The platform's deployment list should show one entry for the release, not two.
4. **A missing credential fails the run.** Temporarily unset the deploy secret in a test repo and confirm the job errors instead of skipping. A silent skip is worse than no automation.
5. **The whole chain is hands-off.** From merging the promotion PR, confirm: release PR opens → auto-merges → tag appears → deploy fires. Time it; if any link needs a human, it will be forgotten.

---

## Reverting a release

**Roll _forward_, don't roll back.** Canonical runbook — the templates in `gitflow-init/references/contributing-md.md` and `project-scaffold/references/configs/git-workflow-rule.md` emit a shorter version of this into each repo.

- **Never redeploy an older tag when the app runs migrations on deploy.** The schema has already migrated forward; the old code would run against the new schema and can break in ways the old code was never tested for. Redeploying an old tag is a last resort, and only safe when you are certain the released migrations are backward-compatible with the older code.
- **Do not `git revert` the tagged commit.** With release-please, the tagged commit's own diff is only `CHANGELOG.md` + the version bump — the release's actual code landed one commit earlier, in the `develop → main` promotion merge. Reverting the tag backs out the changelog and leaves the bug in production.
- **Revert the offending feature commits instead.** On a `fix/…` branch off `develop`, `git revert` the PR commit(s) that introduced the bug — or `git revert -m 1 <the promotion-merge commit>` to back out the whole release. PR into `develop` → promote → it ships as the next patch through the normal flow.
- **Fix bad migrations forward.** A new corrective migration, never a down-migration to un-apply a released one.

---

## When root-scoping is wrong: pure multi-deploy monorepos

Root-scoping (part 4) is correct for a repo with **one deployable app** plus internal libraries — the common case, and the only one verified here.

A repo with **multiple independently deployed services** (`apps/web` + `apps/api`, each its own hosted service) needs a different setup, because one repo-wide version can't describe two things that ship separately:

- **Per-component tags** — `include-component-in-tag: true`, giving `web-v1.2.0` / `api-v0.9.3`, with `separate-pull-requests: true` (see the fullstack-monorepo section of `references/release-please.md` for the verified per-component config and its footguns).
- **The `node-workspace` plugin** so a bump to a shared internal library cascades into every dependent service's version — otherwise a lib-only change repeats the "code on main, dead in prod" failure one level down.
- **A deploy step that routes each tag prefix to its own deploy target** — parse the component out of the tag name and POST the matching hook / run the matching CLI.

**This is guidance, not a scaffolded template.** No repo in this fleet runs it, so there is nothing verified to copy. Build it deliberately, and run the first-deploy checklist above per service.

---

## Required secrets and variables

| Name | Kind | Required? | Purpose |
|---|---|---|---|
| `RELEASE_PLEASE_TOKEN` | secret | **yes** | Authors the release PR (so CI runs on it) **and** merges it (so the merge re-triggers the workflow that tags + deploys). See `references/release-please.md`. |
| `RENDER_DEPLOY_HOOK_URL` | secret | **yes** (Render) | The service's deploy hook. The deploy step fails loudly if unset. |
| `RELEASE_AUTOMERGE` | variable | no | Set to `false` to pause auto-merge and review release PRs by hand. Unset = hands-off. |
| `<ALERT_WEBHOOK_SECRET>` | secret | no | Alert channel for the `verify-tag` failure path (`references/release-verification.md`). No-ops when unset. |
