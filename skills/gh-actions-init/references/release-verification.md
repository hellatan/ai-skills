# release verification + failure alerting

A safety-net that fails loudly when a release *should* have been tagged but wasn't — the prerequisite for ever auto-merging release PRs, since it removes "a human happened to be watching the merge" as the only guard. Alerts post to a Discord channel.

It is also the **gate the tagged-only deploy hangs off**: the `Evaluate release outcome` step emits a `released` output that is `true` only when a tag was cut *and* confirmed on the remote, and the deploy step in `references/tagged-deploy.md` runs on nothing else. So this file isn't optional decoration — without it there is no trustworthy signal that a deploy is warranted.

Scaffold this **alongside release-please** (same condition — skip it when release-please is skipped). Three pieces:

1. `verify-tag` + the **recovery notice** — steps appended to the `release-please.yml` job (see `references/release-please.md`). Verification decides when the workflow goes red; the recovery notice is what says so when it goes green again.
2. `.github/workflows/release-health.yml` — a daily sweep + an on-demand self-test.
3. `.github/actions/discord-alert/action.yml` — a shared composite that posts the alert.

The Discord webhook secret is **optional**: the composite no-ops (with a warning) when it's unset, so scaffolding this is harmless even if the user never wires up alerting.

## Choosing the alert channel — ask, don't assume

`<ALERT_WEBHOOK_SECRET>` in the templates below is a **placeholder you fill in at scaffold time**. A Discord webhook URL points at exactly one channel, so the secret *is* the channel: which secret name a repo's workflows read is how that project picks where its alerts land.

**Name the destination channel in the test alert itself.** Substitute `<ALERT_CHANNEL_LABEL>` (a short token, e.g. `gh_errors`) and `<ALERT_CHANNEL>` (the channel as it reads in Discord, e.g. `#gh-errors`) alongside the secret name. A test that only says "alert pipe test" proves a message *arrived* but not that it arrived in the *right place* — a webhook copied from the wrong channel delivers a clean 204 and looks exactly like success. Naming the expected channel in the title and body makes a misroute obvious on sight instead of silently passing. Same for the PR-alerts arm.

Ask the user which secret to use and substitute it into all three files before writing them. Default to **`DISCORD_GH_ERRORS_WEBHOOK`** — the shared errors channel — when they have no preference; a project that wants its own channel (`DISCORD_<PROJECT>_ALERTS`, `DISCORD_DEPLOY_WEBHOOK`, …) just names a different secret. Keep the name identical across `release-please.yml` and `release-health.yml`; a mismatch means half the alerts silently no-op.

To repoint an existing repo later, either overwrite the secret's value with a different channel's webhook URL (name unchanged, nothing to edit) or rename it and update every `secrets.` reference in `.github/workflows/`.

## Choosing the sweep schedule — stagger it

`<CRON_MINUTE>` in the `release-health.yml` template is the second scaffold-time placeholder: pick an **arbitrary minute (1–59, never 0)** per repo. GitHub's scheduler delays — and under load skips — runs in congested slots, and `:00` of every hour is the most congested of all; a skipped run of a freeze-detector is the same silent failure it exists to catch, one level up. The hour is pinned at **08:00 UTC**, a quiet window (US asleep, Europe just starting), so only the minute varies. Vary it per repo (don't reuse one favorite minute across a fleet), and don't ask the user — no one cares when a daily sweep runs, only that it does.

## Why

release-please can merge a release PR, report the run as **success**, and still create **no tag** — e.g. a title-pattern/component mismatch (see the config gotchas in `references/release-please.md`; [googleapis/release-please#2214](https://github.com/googleapis/release-please/issues/2214)). The run is green, nothing is tagged, and a stuck `autorelease: pending` PR then aborts *all* future releases silently. Watching the merge by hand doesn't reliably catch a tag that fails to appear a minute later; a machine check does.

## 1. `verify-tag` — appended to `release-please.yml`

These steps go on the **same** `release-please` job (reusing its runner — no extra job/spin-up). They need `id: release` on the release-please-action step and a checkout for the local composite. The complete `release-please.yml` (with these steps folded in) is in `references/release-please.md`; the verify-specific steps are:

```yaml
# verify-tag — final goal of the whole release setup: a merged release PR MUST
# produce a tag. Catches two failure modes:
#   1. the release-please step failed outright (loud), and
#   2. a release PR merged, the step reported success, but NO tag was created
#      (the silent freeze — a title-pattern/component mismatch; see the config
#      section of release-please.md).
- name: Evaluate release outcome
  id: check
  if: always()
  env:
    RELEASE_OUTCOME: ${{ steps.release.outcome }}
    # Every output the action emitted, as JSON. Read the tags out of THIS, never
    # from steps.release.outputs.release_created / .tag_name — see the
    # namespaced-outputs trap below.
    OUTPUTS_JSON: ${{ toJSON(steps.release.outputs) }}
    HEAD_MSG: ${{ github.event.head_commit.message }}
    REPO: ${{ github.repository }}
    GH_TOKEN: ${{ github.token }}
  run: |
    alert=false
    title=""
    detail=""
    # released=true ONLY when this run cut a tag AND the tag ref is confirmed on
    # the remote (the `-n "$tags"` clean branch below). The tagged-only deploy
    # step keys off this — a freeze/missing-ref case leaves it false, so an
    # untagged or phantom-tag commit is never shipped. See references/tagged-deploy.md.
    released=false
    head_line=$(printf '%s\n' "$HEAD_MSG" | head -n1)

    # Did this push merge a release PR? The release commit's subject is rendered
    # from the config's pull-request-title-pattern, so it is NOT always
    # "chore: release X.Y.Z" — see the component-in-title trap below.
    is_release_merge=false
    if printf '%s' "$head_line" | grep -Eq '^chore(\([^)]*\))?: release +([^ ]+ +)?v?[0-9]+\.[0-9]+\.[0-9]+'; then
      is_release_merge=true
    fi

    # Every tag this run cut, whether the output key is the root `tag_name` or a
    # namespaced `<path>--tag_name`. Covers single-package, non-root package, and
    # per-component monorepo tags (backend-v1.2.0) without knowing the config.
    tags=$(printf '%s' "$OUTPUTS_JSON" | jq -r 'to_entries[] | select(.key | endswith("tag_name")) | .value | select(. != null and . != "")')
    context="releases_created=$(printf '%s' "$OUTPUTS_JSON" | jq -r '.releases_created // "<empty>"'), paths_released=$(printf '%s' "$OUTPUTS_JSON" | jq -r '.paths_released // "<empty>"')"

    # Ground truth is the ref on the remote. Retried, so ref propagation lag right
    # after the tag is cut can't manufacture a false alarm.
    missing=""
    for tag in $tags; do
      found=false
      for attempt in 1 2 3; do
        if gh api "repos/${REPO}/git/ref/tags/${tag}" >/dev/null 2>&1; then
          found=true
          break
        fi
        if [ "$attempt" -lt 3 ]; then sleep 5; fi
      done
      if [ "$found" = "true" ]; then
        echo "OK: tag ${tag} exists."
      else
        missing="${missing} ${tag}"
      fi
    done

    if [ "$RELEASE_OUTCOME" = "failure" ]; then
      alert=true
      title="❌ ${REPO} — release-please step failed"
      detail="The release-please action failed. No release PR / tag / release was produced this run."
    elif [ "$is_release_merge" = "true" ] && [ -z "$tags" ]; then
      alert=true
      title="🟥 ${REPO} — release PR merged but NO TAG created"
      detail="Merged \`${head_line}\` but release-please reported no tag (${context}). This is the silent freeze — check the title-pattern/component config."
    elif [ -n "$missing" ]; then
      alert=true
      title="🟥 ${REPO} — release reported but tag missing"
      detail="release-please reported tag(s):${missing} but the ref does not exist on the remote (${context})."
    elif [ -n "$tags" ]; then
      echo "OK: tagged $(printf '%s' "$tags" | tr '\n' ' ') (${context})."
      released=true
    else
      echo "OK: no release expected this run (feature push or PR-only update)."
    fi

    {
      echo "alert=$alert"
      echo "title=$title"
      echo "released=$released"
      echo "detail<<EOF"
      echo "$detail"
      echo "EOF"
    } >> "$GITHUB_OUTPUT"

- name: Alert on failure
  if: ${{ always() && steps.check.outputs.alert == 'true' }}
  uses: ./.github/actions/discord-alert
  with:
    webhook: ${{ secrets.<ALERT_WEBHOOK_SECRET> }}
    title: ${{ steps.check.outputs.title }}
    description: |
      ${{ steps.check.outputs.detail }}

      **Commit:** [`${{ github.sha }}`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})
      **Repo:** ${{ github.server_url }}/${{ github.repository }}
      [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}) · [Release PRs](${{ github.server_url }}/${{ github.repository }}/pulls?q=is%3Apr+label%3A%22autorelease%3A+pending%22)

- name: Fail the run if a release was expected but missing
  if: ${{ always() && steps.check.outputs.alert == 'true' }}
  run: |
    echo "::error::release verification failed — see the alert"
    exit 1
```

Add `concurrency: { group: release-please, cancel-in-progress: false }` to `release-please.yml` too, so overlapping release runs serialize.

### ⚠️ Never read `steps.release.outputs.release_created` / `.tag_name` directly

Those unprefixed outputs exist **only when the manifest package sits at the repo root** (`"packages": { ".": … }`). `setPathOutput()` in release-please-action namespaces every per-package output for any other path:

```ts
if (path === '.') core.setOutput(key, value); // tag_name
else core.setOutput(`${path}--${key}`, value); // apps/web--tag_name
```

So in a repo whose package is `apps/web`, or any per-component monorepo (`backend`, `frontend` — both configs this skill scaffolds), both keys read back **empty** and a check built on them alerts "NO TAG created" on every single healthy release, forever. That is not hypothetical: it fired on a real 0.26.0 release that had tagged correctly, seconds after the tag was published in the same run.

Only `releases_created` (**plural**) and `paths_released` are top-level regardless of path, and neither carries a tag name — they're context in the alert body, not the signal. Hence `toJSON(steps.release.outputs)` + `endswith("tag_name")`: it finds the tag under whatever key the config produced, and the ref lookup on the remote is what actually decides pass/fail.

Related: `✔ No commits for path: <pkg>, skipping` in a release-merge run is **not** a failure signal — that's the *next* release PR having nothing to include, which is correct right after a release. Don't add an alert for it.

### ⚠️ The release-merge regex must tolerate a component in the title

`is_release_merge` is what arms the **silent-freeze** branch — the single most important check here. It matches the head commit's subject, and that subject is rendered from the config's `pull-request-title-pattern`, **not** fixed. A pattern carrying `${component}` produces a subject with the component name between "release" and the version:

```
chore(main): release  ingest-worker 0.7.0    # two spaces: ${component} renders with a leading space
chore(main): release 1.5.2                   # no component
```

A version-only pattern (`: release [0-9]`) silently fails to match the first form. `is_release_merge` stays `false`, the "merged but NO TAG created" branch becomes unreachable, and the repo gets a verification block that looks installed and cannot ever fire — the exact failure this whole file exists to prevent, reintroduced one level down. Note that this is **independent** of the namespaced-outputs trap above, and hits the same repos: a non-root package path is usually accompanied by `${component}` in the title pattern.

Hence the optional component group and the full `X.Y.Z` anchor:

```
^chore(\([^)]*\))?: release +([^ ]+ +)?v?[0-9]+\.[0-9]+\.[0-9]+
```

Requiring all three version parts is what keeps the optional group from swallowing ordinary commits — `chore: release notes cleanup` must not match. Verified against real release commits in both shapes, plus non-release subjects.

### The recovery notice — every red gets a green

An alert channel that only ever posts red has a gap the reader has to close in their own head: *was that one ever fixed?* Nothing in the channel answers it, so a problem resolved twenty minutes later looks identical to one still burning three days on, and the only way to find out is to go and check by hand — which is the work the alerting was supposed to remove.

So the workflow says so when it comes back. These steps go on the **same** `release-please` job, after the alert steps.

**A workflow run has no memory**, so this is not something a run knows about itself — it is read back out of GitHub's own run record. No gist, no repo variable, no external store, nothing to keep in sync.

#### ⚠️ What the run record can and cannot prove

It proves **the previous run was red**. It does *not* prove an alert was posted, and the notice must not claim otherwise. `alert ⇒ the run fails` holds here (every alert step is followed by a step that exits 1), but the converse does not: a `startup_failure` creates no jobs at all, a job timeout never reaches the alert steps, a failed `actions/checkout` skips them, and a webhook that is set but revoked fails the run *because* the push failed. All four go red with nothing in the channel.

So the copy stays on the conclusion — "run #N concluded **failure**; this run finished clean, so the workflow is green again" — and never tells the reader they saw something they may not have. The residual is a green that follows a red nobody was shown; that is mildly odd but harmless, and it is strictly better than the alternative, since those are exactly the runs that alert nothing and would otherwise recover in total silence. **A green asserting "…and alerted here" would be a false claim about the reader's own history — don't write one** unless you add a marker the alerting path itself writes.

#### Two lookups, and why the second one is not enough on its own

1. **Earlier attempts of *this* run** — `actions/runs/{run_id}/attempts/{n}`, walked newest-first.
2. **Earlier completed runs** of this workflow on this branch and event — `actions/workflows/{file}/runs?branch=…&event=…&status=completed`, walked newest-first from the highest `run_number` strictly below this one.

The obvious design is (2) alone, and it is **wrong in the single most common recovery path**. A re-run keeps its `run_number` and overwrites its own `conclusion`, so a workflow fixed by hitting **Re-run** — the first thing anyone does after rotating a credential — ends up looking, to a run-number-only lookup, exactly like a workflow that was never broken. The previous *run* was green; the previous *attempt* was the failure, and it has been overwritten in place.

That is not hypothetical. It is what the incident that prompted this feature actually did: a shared fine-grained PAT expired, the release run failed with `Bad credentials`, the token was rotated, and the **same run** was re-run to green — attempts 1 and 2 `failure`, attempt 3 `success`, `run_number` never moving. A run-number-only notice posts nothing at all there.

#### The three-way classification is load-bearing in both directions

Each earlier conclusion is one of three things, and **both** of the non-obvious cases are a real bug if you collapse them:

| Class | Conclusions | Effect on the scan |
| --- | --- | --- |
| red | `failure`, `timed_out`, `startup_failure` | stop — this run clears it |
| clean | `success` | **stop** — anything older is already closed out |
| transparent | `cancelled`, `skipped`, everything else | **keep looking** |

- Treating `clean` as transparent means re-running an already-green run walks past the `success` to the failure underneath and re-posts a green for something closed hours ago.
- Treating `transparent` as clean means one cancelled retry buries the failure under it **permanently** — every future run is now newer than the failure, so nothing ever resolves it. Cancellations are ordinary here: a queued push behind a 30-minute auto-merge poll, or a human cancelling a stuck run.

This is why lookup (2) walks the page rather than reading `sort_by(.run_number) | last`. It is also what makes `per_page=30` mean something. The window is still finite: more than 30 consecutive transparent runs and the failure falls off the end, which fails *quiet*, not wrong.

#### ⚠️ `actions: read` — and it is not implied

Both lookups read the workflow's own run history, which needs the `actions` scope. `release-please.yml` **declares a `permissions:` block, and declaring one sets every unlisted scope to `none`** ([GitHub docs](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#permissions): "If you specify the access for any of these permissions, all of those that are not specified are set to `none`") — the same trap as `checks` / `statuses` for the auto-merge gate. Without it every lookup 403s, on every run, and the notice never fires. Add it in the same change as the steps:

```yaml
permissions:
  contents: write
  pull-requests: write
  checks: read
  statuses: read
  actions: read # the recovery notice reads this workflow's own runs + attempts
```

#### Three states, and why "could not tell" is one of them

| `state` | When | What posts |
| --- | --- | --- |
| `resolved` | this run did not alert **and** the most recent earlier state (attempt, else run) was red | green embed (`3066993`) |
| `quiet` | this run alerted, or the most recent earlier state was clean, or there is none | nothing |
| `unknown` | a lookup could not be answered — 403, network, or a body that is not a run list | red embed **and the run fails** |

`unknown` exists because the alternative is the failure this whole file is about, one level up. A `2>/dev/null || true` on the lookup, or a jq expression that lets an API *error object* fall through as "no earlier runs", turns a broken recovery mechanism into a silent green — installed, never firing, indistinguishable from healthy. Hence the explicit shape assertion in the jq (`error(...)` when there is no `.workflow_runs` array) and the separate fail step.

Failing the run on `unknown` marks an otherwise-successful release red, which is deliberate and self-limiting: it stops the moment the lookup works again, and the next clean run then posts the green that closes its own loop. It is also the only notification that needs no webhook at all — see the tier table below.

#### What it must not key off

**Not the branch tip.** A tip is a *state*, not an event: a tip-derived signal reports the same thing on every run and cannot distinguish "just recovered" from "was never broken". A previous port of alerting logic in this family keyed off `github.event.head_commit.message` and inverted for exactly this reason — in the healthy resting state the tip already carried the signature it was looking for, so it cried wolf on every dispatch.

**Not `always()`.** The step is gated on `success()`, which is true only when no previous step in the job has failed. A failure in an *earlier* step — the checkout, or the Discord push itself — means this run is red, and a red run must never announce itself green. Skipped steps do not clear `success()`, so the alert steps above being *skipped* on a healthy run leaves the guard intact.

#### The steps

```yaml
# ── recovery notice ───────────────────────────────────────────────────
# A red alert with no green follow-up leaves the channel's last word on a
# problem that may have been fixed hours ago, so whoever read it has to
# carry "was that ever resolved?" around by hand. Every red is therefore
# paired with a green on the next clean finish of this workflow.
#
# A run has no memory, so "green again" is not something this run can know
# — it is read back out of GitHub's own record.
#
# Deliberately NOT derived from what main currently points at: a branch
# tip is a state, not an event, so a tip-derived signal says the same
# thing on every run and cannot tell "just recovered" from "was never
# broken".
#
# TWO lookups, in this order, because a workflow can go green either way:
#   1. an earlier ATTEMPT of THIS run (someone hit "Re-run"), and
#   2. earlier completed RUNS of this workflow on this branch + event.
# (1) is not an optimisation. A re-run keeps its run_number and overwrites
# its own conclusion, so a repo fixed by re-running the failed run looks,
# to a run-number-only lookup, exactly like a repo that was never broken —
# and the credential-expiry incident this was built for was fixed exactly
# that way (run #96 attempts 1 and 2 failed, attempt 3 succeeded).
- name: Evaluate recovery
  id: recovery
  # No `always()`. A failure in an EARLIER step — the checkout, or the
  # Discord push itself — means this run is red, and a red run must never
  # announce itself green. `success()` is exactly that guard. The alert
  # steps above are *skipped*, not failed, on a healthy run, so this still
  # runs in the case it exists for.
  if: ${{ success() }}
  env:
    # Reading a workflow's own runs and attempts needs `actions: read`.
    # This workflow declares a permissions block, which sets every
    # unlisted scope to `none`, so the scope is granted explicitly above —
    # without it both lookups 403 on every run.
    GH_TOKEN: ${{ github.token }}
    REPO: ${{ github.repository }}
    SERVER_URL: ${{ github.server_url }}
    COMMIT_SHA: ${{ github.sha }}
    # "<owner>/<repo>/.github/workflows/<file>@<ref>" — the file name is
    # derived from it below so this block carries no hardcoded filename.
    WORKFLOW_REF: ${{ github.workflow_ref }}
    BRANCH: ${{ github.ref_name }}
    EVENT: ${{ github.event_name }}
    RUN_ID: ${{ github.run_id }}
    RUN_NUMBER: ${{ github.run_number }}
    RUN_ATTEMPT: ${{ github.run_attempt }}
    # EVERY step in this job that can alert. Moving this block to another
    # workflow means replacing these with that job's own alert-emitting
    # step ids — see references/release-verification.md.
    CHECK_ALERT: ${{ steps.check.outputs.alert }}
    AUTOMERGE_ALERT: ${{ steps.automerge.outputs.alert }}
  run: |
    state=quiet
    color=""
    title=""
    detail=""
    emit() {
      {
        echo "state=$state"
        echo "color=$color"
        echo "title=$title"
        echo "detail<<EOF"
        echo "$detail"
        echo "EOF"
      } >> "$GITHUB_OUTPUT"
    }

    # A green posted alongside this run's own red alert is worse than no
    # notice at all, so a run that alerted says nothing here.
    if [ "$CHECK_ALERT" = "true" ] || [ "$AUTOMERGE_ALERT" = "true" ]; then
      echo "This run alerted — no recovery notice."
      emit
      exit 0
    fi

    wf_file="${WORKFLOW_REF%@*}"
    wf_file="${wf_file##*/}"

    # stderr goes to a FILE, never into the value via 2>&1: a successful
    # call that happens to warn on stderr would otherwise be spliced into
    # the JSON and fail the parse for the wrong reason.
    err=$(mktemp)
    unknown=false

    # "Could not determine" is its own outcome, never a quiet pass. A
    # swallowed lookup failure is how a recovery mechanism ends up
    # installed, silent, and indistinguishable from healthy.
    fail_unknown() {
      unknown=true
      state=unknown
      color="15158332"
      title="🟧 ${REPO} — recovery-notice lookup failed"
      detail=$(printf '%s\n' \
        "Could not read the earlier runs of \`${wf_file}\`, so this run cannot tell whether it clears an earlier failure. **Recovery notices are dead until this is fixed** — a red alert in this channel may already have been resolved with nothing posted to say so." \
        "" \
        "Most likely cause: this workflow's \`permissions:\` block is missing \`actions: read\`." \
        "" \
        '```' \
        "$(head -c 400 "$err" | iconv -f utf-8 -t utf-8 -c)" \
        '```' \
        "" \
        "[View run](${SERVER_URL}/${REPO}/actions/runs/${RUN_ID})")
      echo "::error::recovery-notice lookup failed — see this run's summary."
    }

    # What an earlier conclusion says about health. The three-way split is
    # load-bearing in both directions:
    #   red         — it went red; this run clears it.
    #   clean       — it finished green, so anything older is already
    #                 closed out. STOPS the scan, or a re-run of an
    #                 already-green run re-posts a green for a failure
    #                 that was closed hours ago.
    #   transparent — it never reported either way (cancelled, skipped,
    #                 …). Must NOT stop the scan, or one cancelled retry
    #                 buries the failure underneath it permanently.
    classify() {
      case "$1" in
        failure | timed_out | startup_failure) echo red ;;
        success) echo clean ;;
        *) echo transparent ;;
      esac
    }

    verdict=""
    red_label=""
    red_url=""
    red_conclusion=""

    note_state() {
      case "$(classify "$1")" in
        red)
          verdict=red
          red_label="$2"
          red_url="$3"
          red_conclusion="$1"
          ;;
        clean) verdict=clean ;;
      esac
    }

    # 1. Earlier attempts of THIS run, newest first.
    attempt=$((RUN_ATTEMPT - 1))
    while [ "$attempt" -ge 1 ] && [ -z "$verdict" ]; do
      if ! conclusion=$(gh api "repos/${REPO}/actions/runs/${RUN_ID}/attempts/${attempt}" --jq '.conclusion // ""' 2>"$err"); then
        fail_unknown
        break
      fi
      echo "Run #${RUN_NUMBER} attempt ${attempt} concluded '${conclusion}'."
      note_state "$conclusion" "run #${RUN_NUMBER} attempt ${attempt}" \
        "${SERVER_URL}/${REPO}/actions/runs/${RUN_ID}/attempts/${attempt}"
      attempt=$((attempt - 1))
    done

    # 2. Earlier completed RUNS — also the fall-through when this is a
    # re-run whose earlier attempts were all transparent.
    if [ "$unknown" = "false" ] && [ -z "$verdict" ]; then
      if ! runs_json=$(gh api "repos/${REPO}/actions/workflows/${wf_file}/runs?branch=${BRANCH}&event=${EVENT}&status=completed&per_page=30&exclude_pull_requests=true" 2>"$err"); then
        fail_unknown
      else
        # Newest first, strictly older than this run. run_number is
        # monotonic per workflow and a re-run keeps its original number,
        # so "strictly lower" is the ordering that survives re-runs;
        # excluding this run's own id covers the window where the API
        # lists it before its conclusion is written.
        #
        # The shape assertion is load-bearing. A body that parses as JSON
        # but is not a run list — an API error object, say — would
        # otherwise come back as "no earlier runs", i.e. a silent pass,
        # which is the exact failure this mechanism exists to remove.
        if ! prev_list=$(printf '%s' "$runs_json" | jq -r \
          --argjson rid "$RUN_ID" --argjson rnum "$RUN_NUMBER" '
            if type == "object" and (.workflow_runs | type) == "array" then
              .workflow_runs
              | map(select(.id != $rid and .run_number < $rnum))
              | sort_by(.run_number)
              | reverse
              | .[]
              | "\(.run_number)\t\(.id)\t\(.conclusion // "")"
            else
              error("response has no .workflow_runs array")
            end' 2>"$err"); then
          fail_unknown
        else
          # A here-doc, not a pipe: a `while read` on the right of a pipe
          # runs in a subshell and every verdict it sets is discarded.
          while IFS=$'\t' read -r prev_number prev_id prev_conclusion; do
            [ -n "$prev_number" ] || continue
            echo "Run #${prev_number} (${prev_id}) concluded '${prev_conclusion}'."
            note_state "$prev_conclusion" "run #${prev_number}" \
              "${SERVER_URL}/${REPO}/actions/runs/${prev_id}"
            [ -z "$verdict" ] || break
          done <<EOF
    $prev_list
    EOF
        fi
      fi
    fi

    if [ "$unknown" = "false" ] && [ "$verdict" = "red" ]; then
      state=resolved
      color="3066993" # Discord green
      # Says only what the run record actually proves. A red RUN is not
      # the same claim as "an alert was posted" — a startup_failure or a
      # failed checkout runs no alert step at all — so the copy stays on
      # the conclusion and never asserts the reader saw something.
      title="✅ ${REPO} — ${wf_file} is green again"
      detail=$(printf '%s\n' \
        "[${red_label}](${red_url}) of \`${wf_file}\` concluded **${red_conclusion}**. This run finished clean, so the workflow is **green again** — nothing left to chase." \
        "" \
        "**Commit:** [\`${COMMIT_SHA}\`](${SERVER_URL}/${REPO}/commit/${COMMIT_SHA})" \
        "**Repo:** ${SERVER_URL}/${REPO}" \
        "[View run](${SERVER_URL}/${REPO}/actions/runs/${RUN_ID}) · [Red run](${red_url})")
    elif [ "$unknown" = "false" ]; then
      echo "Nothing to resolve (verdict='${verdict:-none found}')."
    fi
    emit

# One step for both outcomes — the green "green again" notice and the red
# "the lookup itself is broken" notice. Colour and copy come from the step
# above, so there is exactly one Discord call here and no way for the two
# to double-post.
- name: Post the recovery notice
  if: ${{ steps.recovery.outputs.state == 'resolved' || steps.recovery.outputs.state == 'unknown' }}
  uses: ./.github/actions/discord-alert
  with:
    webhook: ${{ secrets.<ALERT_WEBHOOK_SECRET> }}
    color: ${{ steps.recovery.outputs.color || '15158332' }}
    title: ${{ steps.recovery.outputs.title }}
    description: ${{ steps.recovery.outputs.detail }}


# A lookup that cannot answer "was the last run red?" is the alerting system
# failing to report on itself, and it must not hide behind a green checkmark.
# The release itself already succeeded, so this is a deliberately loud,
# self-limiting red: it stops the moment the lookup works again, and the next
# clean run then posts the green that closes the loop.
- name: Fail the run if the recovery lookup broke
  if: ${{ always() && steps.recovery.outputs.state == 'unknown' }}
  run: |
    echo "::error::could not determine whether this run clears an earlier failure — recovery notices are not working until this is fixed."
    exit 1
```

#### ⚠️ Moving this block to another workflow

It is close to portable but **not** drop-in, and the two things that bind it to this job are both silent if you miss one.

`github.workflow_ref` is `<owner>/<repo>/.github/workflows/<file>@<ref>`, so the workflow *file name* is derived rather than hardcoded and needs no edit. What does need editing:

1. **`CHECK_ALERT` / `AUTOMERGE_ALERT` name this job's alerting steps.** They must be replaced with the ids of **every** step in the destination job that can post an alert. Get this wrong and the guard is inert: the job posts its own red *and* a green from the same run — the one arrangement this design exists to make impossible. If you cannot enumerate a job's alerting steps, do not move the block into it.
2. **The step ids must exist.** `actionlint` hard-fails on `steps.automerge.outputs.alert` in a workflow with no `automerge` step (`property "automerge" is not defined in object type …`), so a repo that scaffolds `verify-tag` **without** the auto-merge step from `references/tagged-deploy.md` must edit these before the workflow will lint.

The `event=` filter is a third thing to think about, in both directions. In a workflow with one trigger it is a no-op. In one with heterogeneous triggers it is what stops a `workflow_dispatch` self-test "resolving" a `schedule` failure it knows nothing about — but it also *partitions* the history, so adding a `workflow_dispatch:` to a `push`-only workflow later means dispatched runs can never resolve pushed failures. Keep the filter and know that trade, or drop it deliberately.

#### Testing it

The `run:` body is code, so run it before committing — not proofread, run. Parse the workflow, pull the step's script out of the parsed YAML *verbatim* (never retype it; a retyped snippet tests a different program than the one that ships), build its environment **from the step's own `env:` block** and hard-error on any variable the script reads that the block does not declare, stub `gh` so it routes on the URL and applies `--jq` like the real thing and *fails loudly* on a URL no fixture models, and cover every verdict the state table can produce — both re-run paths, both `unknown` sources, and a transparent state in front of a red one.

Then mutate. Each mutant must redden **its own** case and leave the others green; one that reddens everything proves nothing. The mutants that matter most are the ones standing in for a design that was already tried and falsified: *skip the attempt scan*, *stop the run scan at the first entry*, and *treat a clean conclusion as transparent*. If any of those stays green, the harness is not modelling the failure it was built for.

## 2. `.github/workflows/release-health.yml`

```yaml
name: release-health

# Two jobs:
#  - self-test: on-demand, fires ONE sample alert to prove the pipe.
#  - pending-sweep: daily, flags any MERGED release PR stuck on
#    "autorelease: pending" (the deadlock that aborts all future releases).

on:
  schedule:
    - cron: "<CRON_MINUTE> 8 * * *" # 08:<CRON_MINUTE> UTC daily — off-peak hour, staggered minute
  workflow_dispatch:
    inputs:
      test_alert:
        description: "Fire a test alert and exit"
        type: boolean
        default: false

permissions:
  contents: read
  pull-requests: read

jobs:
  self-test:
    if: ${{ github.event_name == 'workflow_dispatch' && inputs.test_alert }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Send test alert
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<ALERT_WEBHOOK_SECRET> }}
          color: "3066993" # green — this is a test, not a real failure
          title: "✅ ${{ github.repository }} — <ALERT_CHANNEL_LABEL> pipe test"
          description: |
            Test alert from `release-health.yml`. If you can read this in **<ALERT_CHANNEL>**, delivery works.
            [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})

      # Second channel, included ONLY when this repo also scaffolds the
      # main→develop back-merge (which alerts a different channel — see
      # references/main-to-develop-backmerge.md). Its real alert fires only on a
      # merge conflict, which cannot be manufactured on demand, so without this
      # step that webhook is the one credential in the whole setup with no way
      # to prove it works until the day it's needed. No `if:` guard is needed:
      # the composite no-ops with a warning when the secret is unset.
      - name: Send test alert — PR alerts channel
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<PR_ALERT_WEBHOOK_SECRET> }}
          color: "3066993"
          title: "✅ ${{ github.repository }} — <PR_ALERT_CHANNEL_LABEL> pipe test"
          description: |
            Test alert from `release-health.yml`. If you can read this in **<PR_ALERT_CHANNEL>**, delivery works.
            [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})

  pending-sweep:
    if: ${{ github.event_name == 'schedule' || !inputs.test_alert }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: "Find stuck 'autorelease: pending' PRs"
        id: sweep
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
        run: |
          # The freeze signal is a MERGED release PR still labelled pending: the
          # label flips to "autorelease: tagged" within seconds of a healthy
          # merge, so a merged+pending PR means the tag never happened. (Open +
          # pending is the NORMAL state of an un-merged release PR — never flag those.)
          stuck=$(gh pr list -R "$REPO" --state merged --label "autorelease: pending" \
            --json number,title,url,mergedAt \
            --jq '[.[] | "• [#\(.number) \(.title)](\(.url)) — merged \(.mergedAt)"] | join("\n")')
          if [ -n "$stuck" ]; then
            echo "$stuck"
            {
              echo "alert=true"
              echo "detail<<EOF"
              echo "$stuck"
              echo "EOF"
            } >> "$GITHUB_OUTPUT"
          else
            echo "alert=false" >> "$GITHUB_OUTPUT"
            echo "no stuck pending release PRs."
          fi
      - name: Alert on failure
        if: steps.sweep.outputs.alert == 'true'
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<ALERT_WEBHOOK_SECRET> }}
          title: "🟥 ${{ github.repository }} — release PR stuck on autorelease: pending"
          description: |
            A **merged** release PR never got tagged, so it is stuck `pending`. **This aborts all future releases until cleared.**

            ${{ steps.sweep.outputs.detail }}

            Fix: relabel to `autorelease: tagged` + re-run, or tag by hand.
            **Repo:** ${{ github.server_url }}/${{ github.repository }}

      # A stuck release PR blocks EVERY future release, so the run must go red.
      # This is the fallback notification path: GitHub emails on a failed run by
      # default, so the finding reaches someone even with no webhook configured.
      # Without it the sweep found the problem and exited 0 — a green checkmark
      # on a frozen release pipeline, which is the exact failure this job exists
      # to catch.
      - name: Fail the run if a release PR is stuck
        if: steps.sweep.outputs.alert == 'true'
        run: |
          echo "::error::a merged release PR is stuck on 'autorelease: pending' — all future releases are blocked until it is cleared. See this run's summary."
          exit 1
```

## 3. `.github/actions/discord-alert/action.yml`

```yaml
name: discord-alert
description: Record an alert on the run summary, and push it to Discord when a webhook is configured.

inputs:
  webhook:
    description: Discord webhook URL — pass the repo's alert webhook secret (default DISCORD_GH_ERRORS_WEBHOOK)
    required: true
  title:
    description: Embed title
    required: true
  description:
    description: Embed description (Discord markdown)
    required: true
  color:
    description: Embed sidebar color (decimal). Default red.
    required: false
    default: "15158332"

runs:
  using: composite
  steps:
    - shell: bash
      env:
        WEBHOOK: ${{ inputs.webhook }}
        TITLE: ${{ inputs.title }}
        DESC: ${{ inputs.description }}
        COLOR: ${{ inputs.color }}
      run: |
        # Record the alert on the run itself FIRST, before any webhook call and
        # regardless of whether one is configured. The webhook is a PUSH channel,
        # not the system of record: a repo with no webhook — or one whose webhook
        # was revoked — must still be able to find out what happened, from the
        # run page, with no external service involved.
        if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
          {
            echo "### ${TITLE}"
            echo
            echo "${DESC}"
            echo
          } >> "$GITHUB_STEP_SUMMARY"
        fi

        if [ -z "$WEBHOOK" ]; then
          echo "::warning::${TITLE} — no alert webhook configured, so this was not sent to Discord. Full detail is in this run's summary."
          exit 0
        fi
        payload=$(jq -n --arg t "$TITLE" --arg d "$DESC" --argjson c "${COLOR:-15158332}" \
          '{embeds:[{title:$t, description:$d, color:$c}]}')
        code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
          -H 'Content-Type: application/json' "$WEBHOOK" -d "$payload")
        echo "discord webhook responded: $code"
        case "$code" in
          2*) echo "alert delivered" ;;
          *)  echo "::error::discord webhook failed (HTTP $code)"; exit 1 ;;
        esac
```

## The webhook secret (optional — alerts no-op without it)

```bash
gh secret set <ALERT_WEBHOOK_SECRET> --repo <owner>/<repo>
```

Create the webhook on the channel the project's alerts should land in (Discord → Server Settings → Integrations → Webhooks → Copy Webhook URL) and paste it when prompted. The secret name is whatever was chosen above; the URL inside it is what selects the channel.

Unlike `RELEASE_PLEASE_TOKEN`, this is **not** required — the composite skips the Discord push (with a warning) when the secret is absent, so the release pipeline still functions. Say so in the summary rather than blocking on it.

### The fallback when there's no webhook — alerts must not depend on it

**A webhook must never be the only channel.** It's an external service reached over the network with a credential that can be unset, revoked, or pointed at a deleted channel — so making it the sole path puts a single point of failure in front of the machinery whose entire job is catching failures. The tiers, in the templates above:

| Tier | Configured | Where the alert surfaces |
| --- | --- | --- |
| 0 | nothing at all | `$GITHUB_STEP_SUMMARY` on the run page (full title + body) · `::warning::` / `::error::` annotation · **run goes red** → GitHub's own failure email |
| 1 | webhook secret | everything above, plus the Discord push |

Two rules that make tier 0 real, both of which were missing in the first version of these templates:

1. **Write `$GITHUB_STEP_SUMMARY` before the webhook call, unconditionally.** Not in the `else` branch. The summary is durable, renders as markdown on the run, needs no credential, and survives the webhook being wrong. Logging just the title on the no-webhook path (the original behaviour) throws away the part that says *what* is wrong.
2. **Any job whose finding is actionable must `exit 1`.** `pending-sweep` originally alerted and exited 0, so a stuck `autorelease: pending` PR — which blocks every future release — was found daily and discarded behind a green checkmark. A red run is the only notification that needs no setup whatsoever.

The recovery notice inherits both tiers unchanged — the composite writes `$GITHUB_STEP_SUMMARY` before it ever looks at the webhook, and an `unknown` lookup fails the run — so a repo with no webhook still gets the green notice on its run page and a red run when the mechanism breaks.

The corollary for the alert copy: the annotation should point at the summary rather than trying to cram the body into a single `::warning::` line, since annotations don't render multi-line markdown.

**But "optional" is exactly why it gets forgotten, and the failure mode is silence.** A repo with the workflows and no webhook looks identical to a healthy one: green runs, no alerts, and no alert is also what "nothing is wrong" looks like. Measured on one fleet, **only 1 of 13 repos** had the errors webhook set — every other repo had been no-opping its alerts since the day it was scaffolded, and nothing surfaced it. So:

- Put it in the **post-scaffold action list**, not just a summary line. Optional-but-forgotten is still broken.
- `ci-baseline-audit` check 10 catches this repo-wide after the fact — a workflow that references a secret the repo doesn't have. Scaffold-time is the cheap fix; the audit is the backstop.

### Prove it, don't assume it

Setting the secret is not evidence it works — a revoked webhook, a URL pasted from the wrong channel, or a truncated paste all store fine and fail silently later. GitHub secrets are write-only, so the only proof is delivery:

```bash
gh workflow run release-health.yml -R <owner>/<repo> --ref <default-branch> -f test_alert=true
```

Then confirm from the run log, **not** the run's conclusion — the job exits 0 either way, because a missing webhook is a deliberate no-op:

```bash
gh run view <run-id> -R <owner>/<repo> --log | grep -E 'alert delivered|skipping alert'
```

`alert delivered` only prints on a 2xx from Discord. `skipping alert` means the secret is empty. A green checkmark on its own tells you nothing.

## Activation timing (gitflow)

- `release-health.yml` runs on `schedule` / `workflow_dispatch`, which execute from the **default branch** — so it's live as soon as it lands on `develop`. Self-test it immediately: `gh workflow run release-health.yml -R <owner>/<repo> -f test_alert=true`.
- `verify-tag` lives in `release-please.yml` (`on: push: [main]`), so it **activates on the next develop→main promotion** and truly exercises on the next real release.

## Prettier note

The scaffolded `.prettierignore` (see `project-scaffold/references/configs/node-ts.md`) excludes `*.yml` / `*.yaml`, so prettier never touches workflow YAML and this is a non-issue for scaffolded repos. It only bites a repo that runs `prettier --check` over `.github` **without** that carve-out (`.github/**` isn't ignored by default) — there the emitted YAML must be prettier-clean or `format:check` fails on the scaffolding PR. These templates are formatted to prettier defaults (`printWidth: 100`, `tabWidth: 2`); if such a repo's `.prettierrc` differs, either add `*.yml`/`*.yaml` (or `.github/`) to its `.prettierignore` — the standard fix — or run `prettier --write` on the three emitted files before committing.

Separately, `CHANGELOG.md` and `.github/.release-please-manifest.json` must be in `.prettierignore` in every repo that runs `prettier --check .` — release-please rewrites both on every release PR and its output doesn't reliably satisfy prettier, so without the carve-out the release PR itself fails `format:check` and auto-merge freezes the release (see `release-please.md`, "Manifest — match current version").
