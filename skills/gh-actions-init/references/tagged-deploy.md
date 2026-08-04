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

**The answer differs for a brand-new service vs. an existing one, and mixing them up is the most-copied mistake here:**

- **A service that already exists** (retrofitting a repo that's been deploying on every push): `render.yaml` alone does **nothing**. `autoDeploy: false` only takes effect once the Blueprint is re-synced in the dashboard — until then the platform keeps deploying every push to `main` and the whole model is silently inert. **Flip auto-deploy off on the service in the dashboard**, or re-sync the Blueprint, and verify it stuck. Same class of step on every other platform: the setting lives in the platform, the file only declares it.
- **A brand-new service created from a `render.yaml` that already carries `autoDeploy: false`** is created with auto-deploy off from the start. There is nothing to "flip off later" — don't send the user hunting for a dashboard toggle that's already correct. Just confirm it after creating the service.

### 2. A deploy step inside `release-please.yml`, gated on a verified tag

Not a separate `deploy.yml` on `on: push: tags` — see the loop-guard gotcha below. The step runs in the **same job** that cut the tag and keys off the `released` output from the `verify-tag` steps (`references/release-verification.md`), which is `true` only when a tag was cut **and** the ref was confirmed on the remote.

`github.sha` on that run **is** the commit release-please just tagged, so passing it as the deploy ref guarantees the platform builds the tagged commit and never the untagged promotion merge.

The step is additionally gated on a repo variable, `RENDER_DEPLOY`, so a repo that has release automation but **no service yet** doesn't fail its releases — see "Repos with no deploy target yet" below. That gate is about *whether this repo deploys at all*; it never softens the failure when a repo that **does** deploy is missing its credential.

### 3. Auto-merge the release PR — **gated on that PR's own CI**

So a release is hands-off after the single human gate. Three load-bearing details, all of which silently break the chain if got wrong — see the step below.

> **Scope: this part is not deploy-specific — scaffold it in every release-please repo.** The other four parts only matter when a tag ships something; this one earns its keep anywhere, because without it every release needs a human to merge the release PR by hand. It was previously rolled out only alongside deploys, which left most repos releasing manually and made the split look like a deliberate policy it never was. If a repo has `release-please.yml`, it should have this step.
>
> Two prerequisites, both of which the step needs regardless of deploys: a `RELEASE_PLEASE_TOKEN` repo secret, and the `.github/actions/discord-alert` composite for the failure path. And **the repo's CI must run on PRs targeting the release branch** — otherwise no checks ever register on the release PR, the grace period expires, and the gate correctly refuses to merge every time. Verify that trigger before scaffolding, not after.
>
> In a repo where a tag ships nothing, drop the deploy wording from the step's comments ("tags and deploys production" → "cuts the release tag", "no tag, no deploy" → "no tag, no release"). The logic is unchanged.

The third one is the easiest to get wrong and the most expensive: the merge **must wait for the release PR's checks**, because that merge is what tags and therefore deploys. `gh pr merge --auto` does not do this on these repos — it needs `allow_auto_merge` on *and* a required status check to wait on, and required checks need branch protection, unavailable on free-plan private repos. So the step polls the checks itself, and refuses to merge (leaving the PR open, alerting) on failure, no checks, or timeout.

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
#
# OPT-OUT SWITCH: set the repo variable RENDER_DEPLOY=false when this repo has
# NO deploy target yet (no service, therefore no deploy hook to configure) —
# the step skips cleanly and releases still tag. Unset (or anything but
# 'false') = this repo deploys, the safe default for anything live.
#
# The two conditions mean DIFFERENT things, deliberately:
#   - RENDER_DEPLOY=false  → "there is nothing to deploy to." Skip, no error.
#   - enabled + missing secret → a REAL error. A repo that deploys and lost its
#     credential must fail loudly, never ship silently nothing. Do not downgrade
#     this to a warning; it is the case protecting a live app.
- name: Deploy tagged release
  if: ${{ steps.check.outputs.released == 'true' && vars.RENDER_DEPLOY != 'false' }}
  env:
    RENDER_DEPLOY_HOOK_URL: ${{ secrets.RENDER_DEPLOY_HOOK_URL }}
    SHA: ${{ github.sha }}
  run: |
    if [ -z "$RENDER_DEPLOY_HOOK_URL" ]; then
      echo "::error::RENDER_DEPLOY_HOOK_URL secret is unset — a release was tagged but production cannot be deployed. Add the deploy hook URL (dashboard → service → Settings → Deploy Hook) as a repo secret. If this repo has no deploy target yet, set the repo variable RENDER_DEPLOY=false instead."
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

**Fail loudly on a missing secret.** The alternative — treating an unset `RENDER_DEPLOY_HOOK_URL` as "nothing to do" — produces a green release that shipped nothing, which is the exact failure class this whole design exists to eliminate. "This repo has no deploy target" must be stated explicitly, as a variable, not inferred from an absent secret.

Required repo secret (for a repo that deploys): **`RENDER_DEPLOY_HOOK_URL`** (dashboard → service → Settings → Deploy Hook). Surface it as a blocking setup step in the report, alongside `RELEASE_PLEASE_TOKEN`.

---

## Repos with no deploy target yet

A freshly scaffolded repo has **no service, therefore no deploy hook**, therefore no `RENDER_DEPLOY_HOOK_URL` to set. Without the `RENDER_DEPLOY` gate, that repo's *first tagged release fails the release workflow* — on a project that was never deployed in the first place. For a scaffold, "not deployed yet" is the normal starting state, so failing on it is backwards.

Hence the two-signal split:

| Situation | `RENDER_DEPLOY` | Deploy hook secret | Behaviour |
|---|---|---|---|
| No service yet (fresh scaffold, internal tool, library) | `false` | absent | Step skips. Releases still tag and publish. No failure. |
| Live app | unset / `true` | set | Deploys the tagged commit. |
| Live app, credential missing or revoked | unset / `true` | absent | **Fails the run.** This is the case worth protecting. |

Set it with `gh variable set RENDER_DEPLOY --body false --repo <owner>/<repo>`; remove it with `gh variable delete RENDER_DEPLOY --repo <owner>/<repo>`.

**Scaffolded repos start at `RENDER_DEPLOY=false`** (and `RELEASE_AUTOMERGE` unset, i.e. auto-merge on). The release chain is then fully working from day one — promote, release, tag — with only the deploy step dormant.

### Go-live checklist (run when the repo actually gets deployed)

1. **Create the service from `render.yaml`.** It already ships `autoDeploy: false`, so the new service is created with auto-deploy **off** — there's nothing to flip afterwards. (Contrast with an *existing* service, which needs the dashboard toggle / Blueprint re-sync; see part 1 above.) Confirm it reads off before continuing.
2. **Add the deploy hook secret:** `gh secret set RENDER_DEPLOY_HOOK_URL --repo <owner>/<repo>` (dashboard → service → Settings → Deploy Hook).
3. **Delete the gate:** `gh variable delete RENDER_DEPLOY --repo <owner>/<repo>` (or set it to `true`).
4. **The next release deploys automatically** — no workflow edit, no re-scaffold. Walk the "verify on your first deploy" checklist below on that first release.

Do these in that order. Deleting the variable before the secret exists leaves a window where a release would fail; the reverse order never does.

---

## The auto-merge step

```yaml
# Auto-merge the release PR so a release is fully hands-off after the one
# human gate (merging the develop→main promotion PR). On a promotion run,
# release-please opens the "chore: release X.Y.Z" PR above; we wait for its
# CI to go green, then squash-merge it here, which pushes to main and fires
# a SECOND release-please.yml run that cuts the tag and deploys (the step
# above).
#
# Four load-bearing details:
#  1. Merge with the PAT, not GITHUB_TOKEN. A GITHUB_TOKEN-authored merge
#     push does NOT re-trigger workflows (GitHub's loop guard), so the
#     tag+deploy run would never happen. Note this applies ONLY to the
#     merge — see 4.
#  2. Find the PR by its `autorelease: pending` label, NOT the action's
#     `pr` output — release-please namespaces per-package outputs, so the
#     bare `pr` output is unreliable (same reason the tag check above uses
#     toJSON, not tag_name).
#  3. WAIT FOR THE PR'S CHECKS. Merging this PR is what tags and deploys
#     production, so merging before CI reports = deploying unverified code.
#     `gh pr merge --auto` is NOT the fix: it errors outright unless the
#     repo has `allow_auto_merge` enabled, and even then it waits only on
#     *required* status checks — which need branch protection, unavailable
#     on free-plan private repos. With none required it merges instantly,
#     which is the bug. So the wait has to live in this step.
#  4. READ the checks with GITHUB_TOKEN, over REST. Only the merge needs
#     the PAT. Reading with it does not work and fails 100% of the time:
#     RELEASE_PLEASE_TOKEN is a fine-grained PAT without `Checks: read`,
#     so `gh pr view --json statusCheckRollup` returns
#       GraphQL: Resource not accessible by personal access token
#       (…pullRequest.statusCheckRollup.nodes.0.commit.statusCheckRollup)
#     on every poll until the timeout. That is exactly how this shipped and
#     it stalled a production release for the full 30 minutes before this
#     was caught — the PAT had always been able to LIST and MERGE PRs,
#     which is all it needed before a step here read check state.
#     The built-in token reads them fine given `checks: read` +
#     `statuses: read` in the permissions block above. REST rather than
#     GraphQL for a second reason: GraphQL quota is per-USER, so a busy
#     local `gh` session on the same account can drain the bucket the
#     release gate depends on. GITHUB_TOKEN's REST budget is per-repo.
# Skipped on the tag-cutting run (released == 'true') and when
# release-please itself failed, so we never merge a stale release PR.
#
# The poll refuses to merge in three cases. Each leaves the release PR
# OPEN and alerts gh_errors — an open release PR is safe (release-please
# just updates it on the next run) but it is also silent: release-health's
# daily sweep only flags MERGED+pending PRs, so nothing else would catch a
# release that stopped here.
#   - a check failed                        → red code must not tag/deploy
#   - no checks registered within the grace  → merging with zero CI is the
#     exact bug this guards against, so silence is treated as failure
#   - checks still running at the timeout    → never block the runner forever
#
# Checks register a few seconds apart, so an immediate "all green" read can
# pass vacuously (one fast job finished, the slow ones not posted yet).
# Green is therefore only accepted once the observed check-name SET has been
# unchanged for CHECKS_SETTLE_SECONDS. Failures are acted on immediately.
#
# PAUSE SWITCH: set the repo variable RELEASE_AUTOMERGE=false to keep the
# release PR OPEN for manual review — e.g. to eyeball the version bump
# after a release-please config change before it tags + deploys. Unset (or
# anything but 'false') = auto-merge on. This gates ONLY the automatic
# merge; when you merge the PR yourself, the tag + deploy still fire.
# Repos with slower CI can raise the wait with the repo variable
# RELEASE_CHECKS_TIMEOUT_SECONDS.
- name: Auto-merge the release PR
  id: automerge
  if: ${{ steps.release.outcome == 'success' && steps.check.outputs.released != 'true' && vars.RELEASE_AUTOMERGE != 'false' }}
  env:
    # Reads run as the built-in token (needs checks:read + statuses:read).
    # The PAT is deliberately NOT the ambient GH_TOKEN — it cannot read
    # check state at all, and using it here stalls every release.
    GH_TOKEN: ${{ github.token }}
    MERGE_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
    REPO: ${{ github.repository }}
    CHECKS_TIMEOUT_SECONDS: ${{ vars.RELEASE_CHECKS_TIMEOUT_SECONDS || '1800' }}
    CHECKS_GRACE_SECONDS: "180"
    CHECKS_SETTLE_SECONDS: "60"
    CHECKS_POLL_SECONDS: "15"
  run: |
    alert=false
    title=""
    detail=""
    emit() {
      {
        echo "alert=$alert"
        echo "title=$title"
        echo "detail<<EOF"
        echo "$detail"
        echo "EOF"
      } >> "$GITHUB_OUTPUT"
    }

    # REST, not `gh pr list` — that is GraphQL, and GraphQL quota is
    # per-user rather than per-repo (see detail 4 above).
    pr=""
    for attempt in 1 2 3; do
      pr=$(gh api "repos/${REPO}/pulls?state=open&base=main&per_page=100" \
        --jq 'map(select(any(.labels[]?; .name == "autorelease: pending")))[0].number // empty' 2>/dev/null || true)
      if [ -n "$pr" ]; then break; fi
      echo "No pending release PR yet (attempt ${attempt}/3), retrying in 5s..."
      sleep 5
    done
    if [ -z "$pr" ]; then
      echo "No pending release PR to auto-merge this run."
      emit
      exit 0
    fi

    pr_url="${GITHUB_SERVER_URL}/${REPO}/pull/${pr}"
    echo "Release PR #${pr} — waiting for its checks (timeout ${CHECKS_TIMEOUT_SECONDS}s)"

    started=$(date +%s)
    seen=""
    stable_since=$started
    outcome=""
    reason=""

    while :; do
      now=$(date +%s)
      elapsed=$((now - started))

      # Re-read the head SHA every poll: release-please can push a new
      # commit to the release PR mid-wait, which restarts its checks.
      # Polling a stale SHA would report the OLD run's results as green.
      # A transient API blip must not be read as "no checks" — retry instead.
      if ! sha=$(gh api "repos/${REPO}/pulls/${pr}" --jq '.head.sha' 2>&1); then
        echo "  [${elapsed}s] could not read the PR head: ${sha}"
        if [ "$elapsed" -ge "$CHECKS_TIMEOUT_SECONDS" ]; then
          outcome=timeout
          reason="Could not read the release PR before the ${CHECKS_TIMEOUT_SECONDS}s timeout."
          break
        fi
        sleep "$CHECKS_POLL_SECONDS"
        continue
      fi

      # Two separate REST endpoints, because they cover different things and
      # a repo can use either: /check-runs is Actions + GitHub Apps (what CI
      # reports here); /status is legacy commit statuses, still emitted by
      # some older integrations. Both are normalised to "<class>\t<name>".
      if ! runs_json=$(gh api "repos/${REPO}/commits/${sha}/check-runs?per_page=100" 2>&1) \
         || ! status_json=$(gh api "repos/${REPO}/commits/${sha}/status" 2>&1); then
        echo "  [${elapsed}s] could not read check status: ${runs_json}${status_json}"
        if [ "$elapsed" -ge "$CHECKS_TIMEOUT_SECONDS" ]; then
          outcome=timeout
          reason="Could not read check status before the ${CHECKS_TIMEOUT_SECONDS}s timeout."
          break
        fi
        sleep "$CHECKS_POLL_SECONDS"
        continue
      fi

      # A check run with no conclusion yet is pending, whatever its status
      # says. Legacy statuses have no status field at all — only .state.
      classified=$(
        printf '%s' "$runs_json" | jq -r '
          .check_runs[]? |
          (if (.status != "completed") or ((.conclusion // "") == "") then "pending"
           elif (.conclusion | . == "success" or . == "neutral" or . == "skipped") then "success"
           else "failure" end) as $cls |
          "\($cls)\t\(.name // "unnamed")"'
        printf '%s' "$status_json" | jq -r '
          .statuses[]? |
          (if (.state == "pending" or (.state // "") == "") then "pending"
           elif (.state == "success") then "success"
           else "failure" end) as $cls |
          "\($cls)\t\(.context // "unnamed")"'
      )

      total=$(printf '%s' "$classified" | grep -c . || true)
      pending=$(printf '%s' "$classified" | grep -c '^pending' || true)
      failing=$(printf '%s' "$classified" | awk -F'\t' '$1=="failure"{print $2}' | paste -sd, - || true)
      names=$(printf '%s' "$classified" | awk -F'\t' '{print $2}' | sort | tr '\n' ',')

      if [ "$names" != "$seen" ]; then
        seen="$names"
        stable_since=$now
      fi
      echo "  [${elapsed}s] checks=${total} pending=${pending} failing='${failing}' stable_for=$((now - stable_since))s"

      if [ -n "$failing" ]; then
        outcome=failed
        reason="Failing check(s): ${failing}."
        break
      fi

      if [ "$total" -eq 0 ]; then
        if [ "$elapsed" -ge "$CHECKS_GRACE_SECONDS" ]; then
          outcome=nochecks
          reason="No checks registered on the release PR within ${CHECKS_GRACE_SECONDS}s. Refusing to merge an unverified release."
          break
        fi
      elif [ "$pending" -eq 0 ] && [ $((now - stable_since)) -ge "$CHECKS_SETTLE_SECONDS" ]; then
        outcome=green
        break
      fi

      if [ "$elapsed" -ge "$CHECKS_TIMEOUT_SECONDS" ]; then
        outcome=timeout
        reason="Checks did not finish within ${CHECKS_TIMEOUT_SECONDS}s (${pending} still pending: ${names%,})."
        break
      fi

      sleep "$CHECKS_POLL_SECONDS"
    done

    if [ "$outcome" != "green" ]; then
      alert=true
      title="🟧 ${REPO} — release PR NOT auto-merged (checks ${outcome})"
      detail="Release PR [#${pr}](${pr_url}) was left **open** — no tag, no deploy. ${reason}"
      echo "::error::${reason} Release PR #${pr} left open."
      emit
      exit 0
    fi

    # ONLY this call uses the PAT — a GITHUB_TOKEN-authored merge push
    # would not re-trigger the workflow that cuts the tag (detail 1).
    echo "All ${total} checks green. Auto-merging release PR #${pr} with the release PAT"
    if ! merge_err=$(GH_TOKEN="$MERGE_TOKEN" gh pr merge "$pr" --repo "$REPO" --squash --delete-branch 2>&1); then
      alert=true
      title="🟧 ${REPO} — release PR merge failed"
      detail="Release PR [#${pr}](${pr_url}) passed CI but the squash-merge failed, so it was left **open** — no tag, no deploy.
    \`\`\`
    ${merge_err}
    \`\`\`"
      echo "::error::Failed to merge release PR #${pr}: ${merge_err}"
      emit
      exit 0
    fi
    echo "Merged release PR #${pr}."
    emit

# Separate from the tag-verification alert below: this one means the release
# STOPPED cleanly (PR open, nothing tagged, nothing deployed), not that a
# release went missing. Different fix, different message — but equally loud,
# because no other job flags an open release PR.
- name: Alert gh_errors — release PR left open
  if: ${{ always() && steps.automerge.outputs.alert == 'true' }}
  uses: ./.github/actions/discord-alert
  with:
    webhook: ${{ secrets.DISCORD_GH_ERRORS_WEBHOOK }}
    title: ${{ steps.automerge.outputs.title }}
    description: |
      ${{ steps.automerge.outputs.detail }}

      Fix the failure, then merge the release PR yourself — the tag + deploy still fire on merge.
      **Repo:** ${{ github.server_url }}/${{ github.repository }}
      [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}) · [Release PRs](${{ github.server_url }}/${{ github.repository }}/pulls?q=is%3Apr+label%3A%22autorelease%3A+pending%22)
```

**Do not scaffold auto-merge without the `verify-tag` steps.** Auto-merge removes "a human happened to be watching" as the only guard that a release actually tagged; the verification steps are what replace it. Scaffold them together, always.

**Wire the new alert into the fail step.** The final "fail the run" step from `references/release-verification.md` keys off `steps.check.outputs.alert`; widen its condition so a refused merge is red in Actions too:

```yaml
if: ${{ always() && (steps.check.outputs.alert == 'true' || steps.automerge.outputs.alert == 'true') }}
```

### Why the step polls instead of using `gh pr merge --auto`

This is the part that gets "simplified" back into a bug. Merging the release PR is what cuts the tag, and under tagged-only deploys the tag *is* the deploy — so **merging before CI reports ships unverified code to production.** The obvious fix looks like `--auto`, and it does not work:

- `--auto` **errors outright** unless the repo has `allow_auto_merge` enabled (it is off by default).
- Even enabled, GitHub's auto-merge waits only on **required** status checks. Required checks come from branch protection, which is **unavailable on free-plan private repos** — so there are none, and `--auto` merges immediately. Same bug, more indirection.

Turning branch protection on isn't the alternative either: on those repos it can't be turned on at all without making the repo public or paying for Pro. Hence the poll.

**⚠️ Read the checks with `GITHUB_TOKEN`, not the release PAT — and grant it `checks: read`.** This is the single most expensive mistake in this step, and it was shipped and hit in production. A fine-grained PAT scoped for release-please (contents + pull-requests) has **no `Checks: read`**, so reading check state with it fails on *every* poll:

```
GraphQL: Resource not accessible by personal access token
(…pullRequest.statusCheckRollup.nodes.0.commit.statusCheckRollup)
```

The PAT can list and merge PRs perfectly well — which is all it ever needed until a step started reading checks — so nothing warns you. The gate simply never passes: every release stalls for the full timeout, alerts, and leaves its PR open. The logic is doing the right thing (unreadable ≠ green), but the pipeline can't complete.

So the step splits its tokens: **reads use `${{ github.token }}`; the PAT is scoped to the single `gh pr merge` call**, the only thing that genuinely requires it. That in turn depends on `checks: read` + `statuses: read` in the workflow's `permissions:` block — and because declaring a block sets every unlisted scope to `none`, the built-in token can't read them either without it. Scaffold the permissions and the step together; either alone is broken.

**Use REST, not GraphQL, for the reads.** Beyond the permission problem, GraphQL's rate limit is per-**user**: a busy local `gh` session on the same account can drain the very bucket the release gate depends on (observed — 5000/hr to zero during one debugging session). `GITHUB_TOKEN`'s REST budget is per-repo and can't be starved that way. `GET /commits/{sha}/check-runs` covers Actions/App check runs and `GET /commits/{sha}/status` covers legacy commit statuses; a repo may use either, so read both.

**Watch the `/status` shape.** That endpoint returns `state: "pending"` with an **empty** `statuses` array when a repo has no legacy commit statuses at all — which is most repos. Keying the classifier off `.state` therefore makes every poll look permanently pending and the gate always times out. Read `.statuses[]` and let an empty array contribute nothing.

**Re-read the head SHA each poll.** release-please can push to the release PR mid-wait, which restarts its checks. A SHA captured once would have the *previous* run's green results read as current.

**The vacuous-pass trap.** Checks register a few seconds apart. A naive "are all checks green?" read moments after the PR is created sees only the one fast job that already finished, calls it green, and merges before the slow jobs have even posted — indistinguishable from a working gate until the day a slow job goes red. That's why green is only accepted once the observed **set of check names** has held steady for `CHECKS_SETTLE_SECONDS`; failures still short-circuit immediately.

**No checks at all is a failure, not a pass.** If nothing registers within `CHECKS_GRACE_SECONDS`, the step refuses to merge. Silence is the state a broken gate produces, and merging with zero CI is exactly what this guards against. A repo whose release PRs genuinely run no checks needs a deliberate decision, not a default that quietly ships.

**Every refusal is loud.** Failure, no-checks, timeout, and a merge that errors all leave the release PR **open** and alert. This matters more than it looks: an open release PR is *not* the freeze signal that `release-health.yml`'s daily sweep looks for (that's a **merged** PR still labelled `autorelease: pending`), so nothing else in the system would ever notice a release that stopped here. Without the alert, releases just quietly stop happening.

Recovery is the pause-switch path: fix the failure, merge the release PR yourself, and the tag + deploy still fire.

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
#   if: ${{ steps.check.outputs.released == 'true' && vars.RENDER_DEPLOY != 'false' }}   # rename the variable to suit (e.g. DEPLOY_ENABLED)
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
#   if: ${{ steps.check.outputs.released == 'true' && vars.RENDER_DEPLOY != 'false' }}   # rename the variable to suit (e.g. DEPLOY_ENABLED)
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

0. **The gate is open.** `RENDER_DEPLOY` is deleted (or `true`) and the deploy credential secret exists. A skipped deploy step looks identical to a successful one in the run summary if you're not reading closely.
1. **Auto-deploy is actually off.** Push a trivial commit to `main` without a release. Nothing should deploy. (Catches the "the file says off, the dashboard says on" trap on a pre-existing service — a service created fresh from a `autoDeploy: false` Blueprint is already correct, but verify rather than assume.)
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
| `RENDER_DEPLOY_HOOK_URL` | secret | **yes, once the repo deploys** | The service's deploy hook. The deploy step fails loudly if unset *while deploys are enabled*. Not needed while `RENDER_DEPLOY=false`. |
| `RENDER_DEPLOY` | variable | no | Set to `false` when the repo has **no deploy target yet** — the deploy step skips cleanly and releases still tag. Scaffolded repos start here. Delete it at go-live. |
| `RELEASE_AUTOMERGE` | variable | no | Set to `false` to pause auto-merge and review release PRs by hand. Unset = hands-off (the scaffolded default). |
| `<ALERT_WEBHOOK_SECRET>` | secret | no | Alert channel for the `verify-tag` failure path (`references/release-verification.md`). No-ops when unset. |
