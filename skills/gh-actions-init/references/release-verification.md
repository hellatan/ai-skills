# release verification + failure alerting

A safety-net that fails loudly when a release *should* have been tagged but wasn't — the prerequisite for ever auto-merging release PRs, since it removes "a human happened to be watching the merge" as the only guard. Alerts post to a Discord channel.

Scaffold this **alongside release-please** (same condition — skip it when release-please is skipped). Three pieces:

1. `verify-tag` — steps appended to the `release-please.yml` job (see `references/release-please.md`).
2. `.github/workflows/release-health.yml` — a daily sweep + an on-demand self-test.
3. `.github/actions/discord-alert/action.yml` — a shared composite that posts the alert.

The Discord webhook secret is **optional**: the composite no-ops (with a warning) when it's unset, so scaffolding this is harmless even if the user never wires up alerting.

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
    RELEASE_CREATED: ${{ steps.release.outputs.release_created }}
    TAG_NAME: ${{ steps.release.outputs.tag_name }}
    HEAD_MSG: ${{ github.event.head_commit.message }}
    REPO: ${{ github.repository }}
    GH_TOKEN: ${{ github.token }}
  run: |
    alert=false
    title=""
    detail=""
    head_line=$(printf '%s\n' "$HEAD_MSG" | head -n1)

    # Did this push merge a release PR? release-please's release commit reads
    # "chore: release X.Y.Z" or "chore(scope): release X.Y.Z".
    is_release_merge=false
    if printf '%s' "$head_line" | grep -Eq '^chore(\([^)]*\))?: release [0-9]'; then
      is_release_merge=true
    fi

    if [ "$RELEASE_OUTCOME" = "failure" ]; then
      alert=true
      title="❌ ${REPO} — release-please step failed"
      detail="The release-please action failed. No release PR / tag / release was produced this run."
    elif [ "$is_release_merge" = "true" ] && [ "$RELEASE_CREATED" != "true" ]; then
      alert=true
      title="🟥 ${REPO} — release PR merged but NO TAG created"
      detail="Merged \`${head_line}\` but release-please reported release_created=${RELEASE_CREATED:-<empty>} and produced no tag. This is the silent freeze — check the title-pattern/component config."
    elif [ "$RELEASE_CREATED" = "true" ]; then
      if [ -n "$TAG_NAME" ] && gh api "repos/${REPO}/git/ref/tags/${TAG_NAME}" >/dev/null 2>&1; then
        echo "OK: release_created=true and tag ${TAG_NAME} exists."
      else
        alert=true
        title="🟥 ${REPO} — release_created but tag missing"
        detail="release-please reported release_created=true (tag_name=${TAG_NAME:-<empty>}) but the tag ref does not exist on the remote."
      fi
    else
      echo "OK: no release expected this run (feature push or PR-only update)."
    fi

    {
      echo "alert=$alert"
      echo "title=$title"
      echo "detail<<EOF"
      echo "$detail"
      echo "EOF"
    } >> "$GITHUB_OUTPUT"

- name: Alert gh_errors
  if: ${{ always() && steps.check.outputs.alert == 'true' }}
  uses: ./.github/actions/discord-alert
  with:
    webhook: ${{ secrets.DISCORD_GH_ERRORS_WEBHOOK }}
    title: ${{ steps.check.outputs.title }}
    description: |
      ${{ steps.check.outputs.detail }}

      **Commit:** [`${{ github.sha }}`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})
      **Repo:** ${{ github.server_url }}/${{ github.repository }}
      [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}) · [Release PRs](${{ github.server_url }}/${{ github.repository }}/pulls?q=is%3Apr+label%3A%22autorelease%3A+pending%22)

- name: Fail the run if a release was expected but missing
  if: ${{ always() && steps.check.outputs.alert == 'true' }}
  run: |
    echo "::error::release verification failed — see the gh_errors alert"
    exit 1
```

Add `concurrency: { group: release-please, cancel-in-progress: false }` to `release-please.yml` too, so overlapping release runs serialize.

## 2. `.github/workflows/release-health.yml`

```yaml
name: release-health

# Two jobs:
#  - self-test: on-demand, fires ONE sample alert to prove the pipe.
#  - pending-sweep: daily, flags any MERGED release PR stuck on
#    "autorelease: pending" (the deadlock that aborts all future releases).

on:
  schedule:
    - cron: "0 14 * * *" # 14:00 UTC daily
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
          webhook: ${{ secrets.DISCORD_GH_ERRORS_WEBHOOK }}
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
      - name: Alert gh_errors
        if: steps.sweep.outputs.alert == 'true'
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.DISCORD_GH_ERRORS_WEBHOOK }}
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
description: Post an alert embed to the gh_errors Discord channel. No-op (warns) if the webhook secret is unset.

inputs:
  webhook:
    description: Discord webhook URL (pass secrets.DISCORD_GH_ERRORS_WEBHOOK)
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
          echo "::warning::DISCORD_GH_ERRORS_WEBHOOK is unset — skipping alert (would have sent: $TITLE)"
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
gh secret set DISCORD_GH_ERRORS_WEBHOOK --repo <owner>/<repo>
```

Create a Discord channel webhook (Server Settings → Integrations → Webhooks → Copy Webhook URL) and paste it when prompted. Unlike `RELEASE_PLEASE_TOKEN`, this is **not** required — the composite skips the alert (with a warning) when the secret is absent, so the release pipeline still functions; you just don't get Discord notifications until it's set.

## Activation timing (gitflow)

- `release-health.yml` runs on `schedule` / `workflow_dispatch`, which execute from the **default branch** — so it's live as soon as it lands on `develop`. Self-test it immediately: `gh workflow run release-health.yml -R <owner>/<repo> -f test_alert=true`.
- `verify-tag` lives in `release-please.yml` (`on: push: [main]`), so it **activates on the next develop→main promotion** and truly exercises on the next real release.

## Prettier note

If the repo runs `prettier --check` over `.github` (many do — `.github/**` is not ignored by default), the emitted YAML must be prettier-clean or `format:check` fails on the scaffolding PR. These templates are formatted to prettier defaults (`printWidth: 100`, `tabWidth: 2`); if the repo's `.prettierrc` differs, run `prettier --write` on the three emitted files before committing. (A repo can instead add `.github/` to `.prettierignore` to opt workflow YAML out of formatting entirely — a per-repo choice, not scaffolded by default.)
