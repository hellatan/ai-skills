# main → develop back-merge

Closes the one gap the promotion flow leaves open: commits that land on `main` and never
come back. Scaffold it **alongside the develop → main promotion workflow** (same scope —
gitflow repos with a `develop` branch), since it exists to keep that workflow honest.

## Why

Every push to `main` adds commits `develop` never sees — the promotion merge commit itself,
and every release-please release commit (CHANGELOG + version bump + manifest). Two costs,
one cosmetic-looking and one that stops you:

- **`develop` lies about the released version.** Its `CHANGELOG.md`, `package.json` version,
  and `.release-please-manifest.json` stay behind `main`'s, and the gap compounds every
  release. Observed: one repo sat 14 commits behind after a few releases.
- **With `main` protection set to `strict: true`** ("require branches to be up to date
  before merging"), the **next** promotion PR is blocked behind an *Update branch* click
  until `develop` contains `main`'s tip. `mergeable_state` reads `behind` rather than
  `clean`. On a repo without that setting the same drift is quieter — but still real.

Doing it by hand works and is what `develop-to-main-pr.md` used to recommend, but it's an
extra step per release that only gets remembered until it doesn't. Three rounds of manual
`chore/backmerge-*` branches in one repo is what prompted automating it.

## ⚠️ Fast-forward FIRST — this is the whole design

Right after a promotion or a release, `main` is a **descendant** of `develop`, so `develop`
can move to `main`'s tip with **no new commit**. Take that path whenever it's available.

A `--no-ff` merge in that situation leaves `develop` permanently **1 commit ahead** of
`main`. `develop-to-main-pr.yml` gates on `git rev-list --count origin/main..origin/develop`,
so it opens a promotion PR containing that lone commit and **zero file changes**. Merging
that PR adds another commit to `main` → which back-merges into `develop` → which opens
another empty PR. Forever. The `--no-ff` fallback can't cause this, because it only fires
when `develop` has genuinely advanced on its own — where the promotion PR is real work.

The reverse mistake is just as easy: a plain `git merge --ff-only main` run by hand **fails
whenever `develop` has commits of its own** ("Not possible to fast-forward, aborting"), and
the follow-up push then reports "Everything up-to-date" — so nothing happened and the branch
stays blocked. The workflow avoids this by running at the moment the fast-forward *is*
possible, and falling back rather than giving up.

## `.github/workflows/main-to-develop-backmerge.yml`

`<PR_ALERT_WEBHOOK_SECRET>` is a scaffold-time placeholder — see
`references/release-verification.md` for how the alert channel is chosen. Default it to
`DISCORD_PR_ALERTS_WEBHOOK`, and keep it **separate from the errors channel**: a conflicted
back-merge is a PR waiting on a human, not a broken pipeline.

```yaml
name: main → develop back-merge

# Every push to `main` — a promotion merge, or a release-please release commit —
# adds commits `develop` never sees, so develop's version and changelog drift
# from the released ones, and with "require branches to be up to date" enabled
# the next develop → main PR is blocked until develop contains main's tip.
#
# Fast-forward FIRST, deliberately. Right after a promotion or a release, main is
# a descendant of develop, so develop can move to main's tip with NO new commit.
# A merge commit here would leave develop permanently 1 commit ahead of main, and
# develop-to-main-pr.yml would open a promotion PR for that lone commit — a PR
# with no file changes, whose merge would add another commit to main, which would
# back-merge into develop, which would open another empty PR. The --no-ff
# fallback only fires when develop has genuinely advanced on its own, where the
# resulting promotion PR is real work rather than an echo.

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read # writes go through the PAT below, never GITHUB_TOKEN

concurrency:
  group: main-to-develop-backmerge
  cancel-in-progress: false

jobs:
  backmerge:
    name: merge main back into develop
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          # Full history — the merge needs both branches, not a shallow tip.
          fetch-depth: 0
          # Push with the PAT, not GITHUB_TOKEN. Two reasons, either one fatal:
          # a GITHUB_TOKEN push triggers no workflows (so develop-to-main-pr.yml
          # never sees the back-merge), and on a protected develop it cannot
          # bypass the pull-request requirement the way an admin-owned PAT can.
          # Same secret release-please.yml and develop-to-main-pr.yml use.
          token: ${{ secrets.RELEASE_PLEASE_TOKEN }}

      - name: Merge main into develop
        id: backmerge
        env:
          GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
        run: |
          # GitHub's own bot identity — 41898282 is the global account ID of
          # github-actions[bot], identical in every repo, not a per-repo or
          # personal value. Leave it as-is: substituting a real person's address
          # attributes automated merge commits to someone who didn't make them.
          # An identity is required, not optional: the --no-ff fallback creates a
          # merge commit, and git refuses to commit without one.
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git fetch origin main develop

          if git merge-base --is-ancestor origin/main origin/develop; then
            echo "develop already contains main ($(git rev-parse --short origin/main)) — nothing to do."
            exit 0
          fi

          git checkout -B develop origin/develop

          if git merge --ff-only origin/main; then
            echo "fast-forwarded develop to main — no merge commit created."
          elif git merge --no-ff origin/main -m "chore: merge main into develop"; then
            echo "develop had commits of its own — merged main in."
          else
            git merge --abort || true
            existing=$(gh pr list --base develop --head main --state open --json number -q '.[0].number // empty')
            if [ -z "$existing" ]; then
              # Only a NEWLY opened PR alerts — a conflict that is already sitting
              # in an open PR would otherwise re-notify on every push to main.
              url=$(gh pr create \
                --base develop \
                --head main \
                --title "chore: merge main into develop (conflict)" \
                --body "The automatic back-merge from \`main\` hit a conflict, so it needs a human. Resolve it here — until then \`develop\` keeps drifting from the released version.

          _Opened by \`.github/workflows/main-to-develop-backmerge.yml\`_")
              echo "pr_url=$url" >> "$GITHUB_OUTPUT"
              echo "opened $url"
            else
              echo "conflict already tracked in PR #${existing} — not re-alerting."
            fi
            echo "::error::back-merge conflicted — resolve the main → develop PR"
            exit 1
          fi

          git push origin HEAD:refs/heads/develop

      # Fires only when the conflict PR was just opened. This is a PR waiting on
      # a human, not a broken pipeline, so it goes to the PR-alerts channel
      # rather than gh_errors — the run itself already went red for the failure.
      # The composite no-ops (with a warning) when the secret is unset.
      - name: Notify PR alerts
        if: ${{ always() && steps.backmerge.outputs.pr_url != '' }}
        uses: ./.github/actions/discord-alert
        with:
          webhook: ${{ secrets.<PR_ALERT_WEBHOOK_SECRET> }}
          color: "15105570" # orange — a PR to merge, not an outage
          title: 🔀 ${{ github.repository }} — main → develop back-merge needs a manual merge
          description: |
            The automatic back-merge from `main` hit a conflict, so it opened a PR for you to resolve and merge. Until it's merged, `develop` stays behind `main` and keeps drifting from the released version.

            **PR:** ${{ steps.backmerge.outputs.pr_url }}
            **Commit:** [`${{ github.sha }}`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})
            [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
```

## Conflicts

A conflict is the one outcome that can't be resolved unattended, so the workflow opens a
`main → develop` PR (`--base develop --head main`, no scratch branch needed), notifies, and
fails the run. Two deliberate details:

- **Only a newly opened PR notifies.** An unresolved conflict would otherwise re-notify on
  every subsequent push to `main` until someone dealt with it, which trains people to mute
  the channel.
- **The run still goes red** independently of the notification. The Discord post is a
  convenience; the failed run is the durable signal.

The alert needs `.github/actions/discord-alert/action.yml` (scaffolded by
`references/release-verification.md`). If verification wasn't scaffolded, add the composite
alongside this workflow or drop the notify step — don't reference an action that doesn't
exist, or the run fails on a missing action instead of alerting.

## Requirements

- **`RELEASE_PLEASE_TOKEN`** — required, same PAT the other bot workflows use. See the token
  section in `references/release-please.md`.
- **`<PR_ALERT_WEBHOOK_SECRET>`** — optional. Unset interpolates to an empty string, the
  composite no-ops with a `::warning::` and exits 0, and everything else still works: the
  conflict PR is opened and the run still fails. Note that Actions secrets can't be shared
  across a personal account — each repo needs its own copy.

## Scope

- **Gitflow repos only** (those with a `develop` branch). A `main`-only repo has nothing to
  back-merge.
- **Skip repos with a `develop → stage → main` topology** — the target to back-merge into
  isn't simply `develop` there, and a two-hop chain needs its own design.

## Activation timing

Triggered by `push: main`, so it activates on the **next** promotion or release, not when it
lands on `develop`. Expect its first run to take the `--no-ff` path if `develop` has work in
flight, and the fast-forward path on every routine release afterwards.

## Verified

Proven on two repos before being scaffolded here — a private app repo (no branch protection,
14 commits of drift) and this one (`strict: true`, promotion PRs actively blocked). Four
real runs across both, all green, **all taking the fast-forward path**, drift cleared to
0 commits behind. The sandbox exercised the other paths: `--no-ff` when `develop` had its own
commit, no-op when `main` was already an ancestor, and a conflict opening a PR + notifying
once (a second push with the PR still open stayed silent).
