# release verification + failure alerting

A safety-net that fails loudly when a release *should* have been tagged but wasn't — the prerequisite for ever auto-merging release PRs, since it removes "a human happened to be watching the merge" as the only guard. Alerts post to a Discord channel.

It is also the **gate the tagged-only deploy hangs off**: the `Evaluate release outcome` step emits a `released` output that is `true` only when a tag was cut *and* confirmed on the remote, and the deploy step in `references/tagged-deploy.md` runs on nothing else. So this file isn't optional decoration — without it there is no trustworthy signal that a deploy is warranted.

Scaffold this **alongside release-please** (same condition — skip it when release-please is skipped). Three pieces:

1. `verify-tag` — steps appended to the `release-please.yml` job (see `references/release-please.md`).
2. `.github/workflows/release-health.yml` — a daily sweep + an on-demand self-test.
3. `.github/actions/discord-alert/action.yml` — a shared composite that posts the alert.

The Discord webhook secret is **optional**: the composite no-ops (with a warning) when it's unset, so scaffolding this is harmless even if the user never wires up alerting.

## Choosing the alert channel — ask, don't assume

`<ALERT_WEBHOOK_SECRET>` in the templates below is a **placeholder you fill in at scaffold time**. A Discord webhook URL points at exactly one channel, so the secret *is* the channel: which secret name a repo's workflows read is how that project picks where its alerts land.

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
          title: "✅ ${{ github.repository }} — alert pipe test"
          description: |
            Test alert from `release-health.yml`. If you can read this, delivery works.
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
```

## 3. `.github/actions/discord-alert/action.yml`

```yaml
name: discord-alert
description: Post an alert embed to a Discord channel. No-op (warns) if the webhook secret is unset.

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
        if [ -z "$WEBHOOK" ]; then
          echo "::warning::alert webhook secret is unset — skipping alert (would have sent: $TITLE)"
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

Unlike `RELEASE_PLEASE_TOKEN`, this is **not** required — the composite skips the alert (with a warning) when the secret is absent, so the release pipeline still functions; you just don't get Discord notifications until it's set. Say so in the summary rather than blocking on it.

## Activation timing (gitflow)

- `release-health.yml` runs on `schedule` / `workflow_dispatch`, which execute from the **default branch** — so it's live as soon as it lands on `develop`. Self-test it immediately: `gh workflow run release-health.yml -R <owner>/<repo> -f test_alert=true`.
- `verify-tag` lives in `release-please.yml` (`on: push: [main]`), so it **activates on the next develop→main promotion** and truly exercises on the next real release.

## Prettier note

The scaffolded `.prettierignore` (see `project-scaffold/references/configs/node-ts.md`) excludes `*.yml` / `*.yaml`, so prettier never touches workflow YAML and this is a non-issue for scaffolded repos. It only bites a repo that runs `prettier --check` over `.github` **without** that carve-out (`.github/**` isn't ignored by default) — there the emitted YAML must be prettier-clean or `format:check` fails on the scaffolding PR. These templates are formatted to prettier defaults (`printWidth: 100`, `tabWidth: 2`); if such a repo's `.prettierrc` differs, either add `*.yml`/`*.yaml` (or `.github/`) to its `.prettierignore` — the standard fix — or run `prettier --write` on the three emitted files before committing.
